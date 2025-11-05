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

/// Top-level function to handle FCM silent push notifications
///
/// This is a "Silent Push" approach where FCM is used only to wake up the app.
/// The payload is empty - FCM doesn't contain any event data.
///
/// Privacy benefits:
/// - Backend doesn't know which user receives which notification
/// - No mapping of recipient_pubkey → FCM token needed
/// - All sensitive data stays encrypted until decrypted locally
///
/// Flow:
/// 1. Backend sends empty FCM push to all users
/// 2. FCM wakes up the app in background
/// 3. App fetches ALL new events from relays
/// 4. App processes and shows notifications for matching sessions
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final logger = Logger();

  try {
    logger.i('FCM silent push received - waking up app');
    logger.d('Message ID: ${message.messageId}');

    // Initialize Firebase in this isolate
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize local notifications system
    await initializeNotifications();

    // Load relay list from settings
    final sharedPrefs = SharedPreferencesAsync();
    final relaysJson = await sharedPrefs.getStringList('settings.relays');
    final relays = relaysJson ?? [];

    if (relays.isEmpty) {
      logger.w('No relays configured - cannot fetch events');
      return;
    }

    logger.i('Fetching new events from ${relays.length} relays...');

    // Fetch and process all new events
    await fetchAndProcessNewEvents(relays: relays);

    logger.i('Silent push processed - all new events fetched and notifications shown');

  } catch (e, stackTrace) {
    logger.e('Error processing silent push: $e');
    logger.e('Stack trace: $stackTrace');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Register FCM background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

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
