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
/// IMPORTANT: This runs in a background isolate where:
/// - Flutter plugins are not initialized
/// - UI context is not available
/// - Heavy operations should be avoided
///
/// This handler only sets a flag that triggers event processing when the app
/// comes to foreground or becomes active.
///
/// Privacy benefits:
/// - Backend doesn't know which user receives which notification
/// - No mapping of recipient_pubkey → FCM token needed
/// - All sensitive data stays encrypted until decrypted locally
///
/// Flow:
/// 1. Backend sends empty FCM push to all users
/// 2. FCM wakes up the app in background
/// 3. This handler sets a flag indicating pending work
/// 4. When app is foregrounded, it fetches and processes events
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final logger = Logger();

  try {
    logger.i('FCM silent push received in background isolate');
    logger.d('Message ID: ${message.messageId}');

    // Initialize Firebase in this isolate (lightweight)
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Set flag for pending event processing
    // This flag will be checked when app comes to foreground
    final sharedPrefs = SharedPreferencesAsync();

    await sharedPrefs.setBool('fcm.pending_fetch', true);
    await sharedPrefs.setInt('fcm.last_wake_timestamp', DateTime.now().millisecondsSinceEpoch);

    logger.i('Background flag set - events will be fetched when app is active');

  } catch (e, stackTrace) {
    logger.e('Error in background handler: $e');
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

  // Setup foreground FCM listener to process events when app is active
  _setupForegroundFCMListener(sharedPreferences, settings);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MostroApp(),
    ),
  );
}

/// Setup FCM foreground listener to process pending events
///
/// This listener runs in the main isolate where all Flutter plugins and UI
/// context are available. It checks for pending events flagged by the
/// background handler and processes them safely.
void _setupForegroundFCMListener(
  SharedPreferencesAsync sharedPrefs,
  SettingsNotifier settings,
) {
  final logger = Logger();

  // Listen for foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    try {
      logger.i('FCM message received in foreground');

      // Process events immediately when app is in foreground
      await _processPendingEvents(sharedPrefs, settings, logger);
    } catch (e, stackTrace) {
      logger.e('Error processing foreground FCM: $e');
      logger.e('Stack trace: $stackTrace');
    }
  });

  // Also check for pending events on app resume
  // This handles events flagged by background handler
  _checkPendingEventsOnResume(sharedPrefs, settings, logger);
}

/// Check and process pending events when app resumes or starts
Future<void> _checkPendingEventsOnResume(
  SharedPreferencesAsync sharedPrefs,
  SettingsNotifier settings,
  Logger logger,
) async {
  try {
    final hasPending = await sharedPrefs.getBool('fcm.pending_fetch') ?? false;

    if (hasPending) {
      logger.i('Pending events detected - processing now');
      await _processPendingEvents(sharedPrefs, settings, logger);
    }
  } catch (e, stackTrace) {
    logger.e('Error checking pending events: $e');
    logger.e('Stack trace: $stackTrace');
  }
}

/// Process pending events by fetching from relays
Future<void> _processPendingEvents(
  SharedPreferencesAsync sharedPrefs,
  SettingsNotifier settings,
  Logger logger,
) async {
  try {
    // Clear the pending flag first to avoid duplicate processing
    await sharedPrefs.setBool('fcm.pending_fetch', false);

    // Get relay list from settings
    final relays = settings.settings.relays;

    if (relays.isEmpty) {
      logger.w('No relays configured - cannot fetch events');
      return;
    }

    logger.i('Fetching new events from ${relays.length} relays...');

    // Fetch and process all new events
    await fetchAndProcessNewEvents(relays: relays);

    logger.i('Successfully processed pending events');
  } catch (e, stackTrace) {
    logger.e('Error processing pending events: $e');
    logger.e('Stack trace: $stackTrace');
  }
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
