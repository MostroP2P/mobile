import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/core/app.dart';
import 'package:mostro_mobile/features/auth/providers/auth_notifier_provider.dart';
import 'package:mostro_mobile/features/relays/relays_provider.dart';
import 'package:mostro_mobile/features/settings/settings_notifier.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/background/background_service.dart';
import 'package:mostro_mobile/features/notifications/services/background_notification_service.dart';
import 'package:mostro_mobile/firebase_options.dart';
import 'package:mostro_mobile/shared/providers/background_service_provider.dart';
import 'package:mostro_mobile/shared/providers/providers.dart';
import 'package:mostro_mobile/shared/utils/biometrics_helper.dart';
import 'package:mostro_mobile/shared/utils/notification_permission_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;

/// Check if the current platform supports Firebase
bool get _isFirebaseSupported {
  if (kIsWeb) return false;
  return Platform.isAndroid || Platform.isIOS;
}

/// FCM background message handler - processes events directly when app is killed
/// Only active on Android and iOS platforms
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final logger = Logger();

  try {
    logger.i('=== FCM BACKGROUND WAKE START ===');
    logger.i('Message data: ${message.data}');

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final sharedPrefs = SharedPreferencesAsync();
    
    // SharedPreferencesAsync always reads fresh values from native storage
    // No reload() needed - it queries the platform directly on each call
    
    // Load settings to get relay configuration
    final settingsJson = await sharedPrefs.getString('mostro_settings');
    List<String> relays = ['wss://relay.mostro.network']; // Default fallback
    
    if (settingsJson != null) {
      try {
        final settingsMap = jsonDecode(settingsJson) as Map<String, dynamic>;
        final relaysList = settingsMap['relays'] as List<dynamic>?;
        if (relaysList != null && relaysList.isNotEmpty) {
          relays = relaysList.cast<String>();
          logger.i('Loaded ${relays.length} relays from settings');
        }
      } catch (e) {
        logger.w('Failed to parse settings, using default relay: $e');
      }
    } else {
      logger.w('No settings found, using default relay');
    }

    // Process events directly in background
    logger.i('Processing events from ${relays.length} relays...');
    
    try {
      await fetchAndProcessNewEvents(
        relays: relays,
        maxEventsPerSession: 10, // Limit to avoid timeout
        timeoutPerSession: const Duration(seconds: 5), // Timeout per session
      );
      
      logger.i('Background event processing completed successfully');
      
      // Update last processed timestamp
      final now = (DateTime.now().millisecondsSinceEpoch / 1000).floor();
      await sharedPrefs.setInt('fcm.last_processed_timestamp', now);
      
    } catch (e, stackTrace) {
      logger.e('Error processing events in background: $e');
      logger.e('Stack trace: $stackTrace');
      
      // Set flag for retry when app opens
      await sharedPrefs.setBool('fcm.pending_fetch', true);
    }

    logger.i('=== FCM BACKGROUND WAKE END ===');
  } catch (e, stackTrace) {
    logger.e('Critical error in background handler: $e');
    logger.e('Stack trace: $stackTrace');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase only on supported platforms (Android, iOS)
  if (_isFirebaseSupported) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

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

  final container = ProviderContainer(
    overrides: [
      settingsProvider.overrideWith((b) => settings),
      backgroundServiceProvider.overrideWithValue(backgroundService),
      biometricsHelperProvider.overrideWithValue(biometricsHelper),
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      secureStorageProvider.overrideWithValue(secureStorage),
      mostroDatabaseProvider.overrideWithValue(mostroDatabase),
      eventDatabaseProvider.overrideWithValue(eventsDatabase),
    ],
  );

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
