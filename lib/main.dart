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

/// Top-level function to handle FCM messages when app is terminated
/// This handler is called in a separate isolate by Firebase Messaging
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final logger = Logger();

  try {
    logger.i('FCM background message received');
    logger.d('Message ID: ${message.messageId}');
    logger.d('Message data: ${message.data}');

    // Initialize Firebase in this isolate
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Validate FCM payload structure
    if (message.data.isEmpty) {
      logger.w('FCM message has empty data payload');
      return;
    }

    // Extract event_id and recipient_pubkey from FCM payload
    final eventId = message.data['event_id'] as String?;
    final recipientPubkey = message.data['recipient_pubkey'] as String?;

    if (eventId == null || recipientPubkey == null) {
      logger.w('FCM message missing required fields - event_id: $eventId, recipient_pubkey: $recipientPubkey');
      return;
    }

    logger.i('Processing FCM notification for event: $eventId');
    logger.d('Recipient pubkey: ${recipientPubkey.substring(0, 16)}...');

    // Initialize local notifications system in this isolate
    await initializeNotifications();

    // TODO: Complete FCM background processing implementation
    //
    // This requires a backend service that:
    // 1. Listens to Nostr relays for kind 1059 (gift-wrapped) events
    // 2. Detects new Mostro messages for registered users
    // 3. Sends FCM push notification with minimal payload:
    //    - event_id: The Nostr event ID
    //    - recipient_pubkey: The trade key public key
    //
    // When FCM message is received here, we need to:
    // 1. Load sessions from Sembast database (using event_id or recipient_pubkey)
    // 2. Initialize NostrService with relay list from settings
    // 3. Fetch the event from relays using event_id
    // 4. Decrypt the event content with the trade key from the session
    // 5. Extract MostroMessage and show local notification
    //
    // Privacy note: FCM payload only contains public data (event_id, pubkey)
    // All sensitive data (amounts, addresses) stays encrypted until decrypted locally

    logger.i('FCM notification logged - Full processing requires backend implementation');
    logger.i('Event: $eventId, Recipient: ${recipientPubkey.substring(0, 10)}...');

  } catch (e, stackTrace) {
    logger.e('Error processing FCM background message: $e');
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
