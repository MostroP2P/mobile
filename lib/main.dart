import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mostro_mobile/core/app.dart';
import 'package:mostro_mobile/features/auth/providers/auth_notifier_provider.dart';
import 'package:mostro_mobile/features/relays/relays_provider.dart';
import 'package:mostro_mobile/features/settings/settings_notifier.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/background/background_service.dart';
import 'package:mostro_mobile/features/notifications/services/background_notification_service.dart';
import 'package:mostro_mobile/services/fcm_service.dart';
import 'package:mostro_mobile/services/push_notification_service.dart';
import 'package:mostro_mobile/shared/providers/background_service_provider.dart';
import 'package:mostro_mobile/shared/providers/providers.dart';
import 'package:mostro_mobile/shared/utils/biometrics_helper.dart';
import 'package:mostro_mobile/shared/utils/notification_permission_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await requestNotificationPermissionIfNeeded();

  final biometricsHelper = BiometricsHelper();
  final sharedPreferences = SharedPreferencesAsync();
  final secureStorage = const FlutterSecureStorage();

  final mostroDatabase = await openMostroDatabase('mostro.db');
  final eventsDatabase = await openMostroDatabase('events.db');

  final settings = SettingsNotifier(sharedPreferences);
  await settings.init();

  await initializeNotifications();

  _initializeTimeAgoLocalization();

  final backgroundService = createBackgroundService(settings.settings);
  await backgroundService.init();

  // Initialize FCM (skip on Linux)
  final pushServices = await _initializeFirebaseMessaging(sharedPreferences);

  final container = ProviderContainer(
    overrides: [
      settingsProvider.overrideWith((b) => settings),
      backgroundServiceProvider.overrideWithValue(backgroundService),
      biometricsHelperProvider.overrideWithValue(biometricsHelper),
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      secureStorageProvider.overrideWithValue(secureStorage),
      mostroDatabaseProvider.overrideWithValue(mostroDatabase),
      eventDatabaseProvider.overrideWithValue(eventsDatabase),
      if (pushServices != null) ...[
        fcmServiceProvider.overrideWithValue(pushServices.fcmService),
        pushNotificationServiceProvider
            .overrideWithValue(pushServices.pushService),
      ],
    ],
  );

  // Initialize relay sync on app start
  _initializeRelaySynchronization(container);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MostroApp(),
    ),
  );
}

/// Initialize relay synchronization on app startup
void _initializeRelaySynchronization(ProviderContainer container) {
  try {
    // Read the relays provider to trigger initialization of RelaysNotifier
    // This will automatically start sync with the configured Mostro instance
    container.read(relaysProvider);
  } catch (e) {
    // Log error but don't crash app if relay sync initialization fails
    debugPrint('Failed to initialize relay synchronization: $e');
  }
}

/// Initialize timeago localization for supported languages
void _initializeTimeAgoLocalization() {
  // Set Spanish locale for timeago
  timeago.setLocaleMessages('es', timeago.EsMessages());

  // Set Italian locale for timeago
  timeago.setLocaleMessages('it', timeago.ItMessages());

  // English is already the default, no need to set it
}

/// Result of Firebase/push notification initialization
class _PushServices {
  final FCMService fcmService;
  final PushNotificationService pushService;

  _PushServices({required this.fcmService, required this.pushService});
}

/// Initialize Firebase Cloud Messaging and Push Notification Service
/// Returns the initialized services, or null if not supported/failed
Future<_PushServices?> _initializeFirebaseMessaging(
    SharedPreferencesAsync prefs) async {
  try {
    // Skip Firebase initialization on Linux (not supported)
    if (!kIsWeb && Platform.isLinux) {
      debugPrint(
          'Firebase not supported on Linux - skipping FCM initialization');
      return null;
    }

    final fcmService = FCMService(prefs);
    await fcmService.initialize();

    // Initialize Push Notification Service (for encrypted token registration)
    final pushService = PushNotificationService(fcmService: fcmService);
    await pushService.initialize();

    // Wire up token refresh to re-register all trade pubkeys
    fcmService.onTokenRefresh = (_) => pushService.reRegisterAllTokens();

    return _PushServices(fcmService: fcmService, pushService: pushService);
  } catch (e) {
    // Log error but don't crash app if FCM initialization fails
    debugPrint('Failed to initialize Firebase Cloud Messaging: $e');
    return null;
  }
}
