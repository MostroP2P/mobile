/// Background Notification Service
///
/// Handles processing of Nostr events for push notifications in both
/// foreground and background contexts.
///
/// ## Architecture
///
/// ### Storage Strategy:
/// - **mostro.db**: Core app data (sessions, orders) - Read/Write in foreground
/// - **notifications.db**: Notification deduplication state - Read/Write in background
/// - **events.db**: (Legacy, no longer used for notifications)
///
/// ### Deduplication:
/// Uses a separate `notification_state` store in `notifications.db` to track
/// which events have been processed. This prevents duplicate notifications and
/// maintains a clean separation between event data and notification state.
///
/// Schema: notification_state store
/// - key: event ID (String)
/// - value: {processed_at: int, notification_shown: bool}
///
/// ### Error Handling:
/// - `showLocalNotification()`: Propagates errors to enable retry mechanisms
/// - `retryNotification()`: Implements exponential backoff (1s, 2s, 4s)
/// - Errors are logged and rethrown for proper handling by callers
///
/// ### Read-only Boundary:
/// Background service maintains read-only access to event/session data:
/// - Reads from mostro.db for session matching and decryption
/// - Writes ONLY to notifications.db for deduplication
/// - Does not modify events.db or mostro.db from background
///
/// ### Silent Push Flow (Current):
/// 1. FCM sends silent wake-up notification
/// 2. App calls `fetchAndProcessNewEvents()`
/// 3. Fetches new events from relays since last check
/// 4. Each event checked against notification_state for duplicates
/// 5. New events decrypted, processed, and notifications shown
/// 6. Event IDs marked as processed in notification_state
library;

import 'dart:convert';
import 'dart:math';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mostro_mobile/core/app.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as mostro_action;
import 'package:mostro_mobile/data/repositories/notification_state_storage.dart';
import 'package:mostro_mobile/data/repositories/session_storage.dart';
import 'package:mostro_mobile/features/key_manager/key_derivator.dart';
import 'package:mostro_mobile/features/key_manager/key_manager.dart';
import 'package:mostro_mobile/features/key_manager/key_storage.dart';
import 'package:mostro_mobile/features/notifications/utils/notification_data_extractor.dart';
import 'package:mostro_mobile/features/notifications/utils/notification_message_mapper.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/generated/l10n_en.dart';
import 'package:mostro_mobile/generated/l10n_es.dart';
import 'package:mostro_mobile/generated/l10n_it.dart';
import 'package:mostro_mobile/background/background.dart' as bg;
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/shared/providers/mostro_database_provider.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> initializeNotifications() async {
  const android = AndroidInitializationSettings('@drawable/ic_bg_service_small');
  const ios = DarwinInitializationSettings();
  const linux = LinuxInitializationSettings(defaultActionName: 'Open');
  const initSettings = InitializationSettings(android: android, iOS: ios, linux: linux, macOS: ios);
  
  await flutterLocalNotificationsPlugin.initialize(initSettings, onDidReceiveNotificationResponse: _onNotificationTap);
}

void _onNotificationTap(NotificationResponse response) {
  try {
    final context = MostroApp.navigatorKey.currentContext;
    if (context != null) {
      context.push('/notifications');
      Logger().i('Navigated to notifications screen');
    }
  } catch (e) {
    Logger().e('Navigation error: $e');
  }
}

/// Show a local notification for a Nostr event
///
/// This function processes a Nostr event and displays a notification.
/// It uses a separate notification_state store for deduplication to avoid
/// processing the same event multiple times.
///
/// Architecture:
/// - Read-only for event data
/// - Writes deduplication state to separate notification_state store
/// - Propagates errors to allow retry mechanisms to work
///
/// Throws: Any error encountered during processing (for retry support)
Future<void> showLocalNotification(NostrEvent event) async {
  final logger = Logger();

  // Step 1: Check if event was already processed (deduplication)
  if (event.id == null) {
    logger.w('Event has no ID, cannot check for duplicates');
    return;
  }

  final notificationDb = await openMostroDatabase('notifications.db');
  final notificationStateStorage = NotificationStateStorage(db: notificationDb);

  final alreadyProcessed = await notificationStateStorage.isProcessed(event.id!);
  if (alreadyProcessed) {
    logger.d('Event ${event.id} already processed, skipping notification');
    return;
  }

  final mostroMessage = await _decryptAndProcessEvent(event);
  if (mostroMessage == null) return;

  final sessions = await _loadSessionsFromDatabase();
  final matchingSession = sessions.cast<Session?>().firstWhere(
    (session) => session?.orderId == mostroMessage.id,
    orElse: () => null,
  );

  final notificationData = await NotificationDataExtractor.extractFromMostroMessage(mostroMessage, null, session: matchingSession);
  if (notificationData == null || notificationData.isTemporary) return;

  final notificationText = await _getLocalizedNotificationText(notificationData.action, notificationData.values);
  final expandedText = _getExpandedText(notificationData.values);

  final details = NotificationDetails(
    android: AndroidNotificationDetails(
      'mostro_channel',
      'Mostro Notifications',
      channelDescription: 'Notifications for Mostro trades and messages',
      importance: Importance.max,
      priority: Priority.high,
      visibility: NotificationVisibility.public,
      playSound: true,
      enableVibration: true,
      ticker: notificationText.title,
      icon: '@drawable/ic_notification',
      styleInformation: expandedText != null
          ? BigTextStyleInformation(expandedText, contentTitle: notificationText.title)
          : null,
      category: AndroidNotificationCategory.message,
      autoCancel: true,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
      subtitle: expandedText,
    ),
  );

  // Show notification - propagate errors for retry support
  await flutterLocalNotificationsPlugin.show(
    event.id.hashCode,
    notificationText.title,
    notificationText.body,
    details,
    payload: mostroMessage.id,
  );

  // Step 2: Mark event as processed to prevent future duplicates
  await notificationStateStorage.markAsProcessed(event.id!);

  logger.i('Notification shown and event marked as processed: ${notificationText.title} - ${notificationText.body}');
}


Future<MostroMessage?> _decryptAndProcessEvent(NostrEvent event) async {
  try {
    if (event.kind != 4 && event.kind != 1059) return null;

    final sessions = await _loadSessionsFromDatabase();
    final matchingSession = sessions.cast<Session?>().firstWhere(
      (s) => s?.tradeKey.public == event.recipient,
      orElse: () => null,
    );

    if (matchingSession == null) return null;

    final decryptedEvent = await event.unWrap(matchingSession.tradeKey.private);
    if (decryptedEvent.content == null) return null;

    final result = jsonDecode(decryptedEvent.content!);
    if (result is! List || result.isEmpty) return null;

    final mostroMessage = MostroMessage.fromJson(result[0]);
    mostroMessage.timestamp = event.createdAt?.millisecondsSinceEpoch;
    
    return mostroMessage;
  } catch (e) {
    Logger().e('Decrypt error: $e');
    return null;
  }
}

Future<List<Session>> _loadSessionsFromDatabase() async {
  try {
    final db = await openMostroDatabase('mostro.db');
    const secureStorage = FlutterSecureStorage();
    final sharedPrefs = SharedPreferencesAsync();
    final keyStorage = KeyStorage(secureStorage: secureStorage, sharedPrefs: sharedPrefs);
    final keyDerivator = KeyDerivator("m/44'/1237'/38383'/0");
    final keyManager = KeyManager(keyStorage, keyDerivator);
    
    await keyManager.init();
    final sessionStorage = SessionStorage(keyManager, db: db);
    return await sessionStorage.getAll();
  } catch (e) {
    Logger().e('Session load error: $e');
    return [];
  }
}

class NotificationText {
  final String title;
  final String body;
  NotificationText({required this.title, required this.body});
}

Future<NotificationText> _getLocalizedNotificationText(mostro_action.Action action, Map<String, dynamic> values) async {
  try {
    final languageCode = bg.currentLanguage;
    
    final S localizations = switch (languageCode) {
      'es' => SEs(),
      'it' => SIt(),
      _ => SEn(),
    };
    
    final title = NotificationMessageMapper.getLocalizedTitleWithInstance(localizations, action);
    final body = NotificationMessageMapper.getLocalizedMessageWithInstance(localizations, action, values: values);
    
    return NotificationText(title: title, body: body);
  } catch (e) {
    final fallback = SEn();
    return NotificationText(
      title: NotificationMessageMapper.getLocalizedTitleWithInstance(fallback, action),
      body: NotificationMessageMapper.getLocalizedMessageWithInstance(fallback, action, values: values),
    );
  }
}



// Get expanded text showing additional values
String? _getExpandedText(Map<String, dynamic> values) {
  if (values.isEmpty) return null;
  
  final List<String> details = [];
  final languageCode = bg.currentLanguage;
  
  final S localizations = switch (languageCode) {
    'es' => SEs(),
    'it' => SIt(),
    _ => SEn(),
  };
  
  // Contact buyer/seller information
  if (values.containsKey('buyer_npub') && values['buyer_npub'] != null) {
    details.add('${localizations.notificationBuyer}: ${values['buyer_npub']}');
  }
  
  if (values.containsKey('seller_npub') && values['seller_npub'] != null) {
    details.add('${localizations.notificationSeller}: ${values['seller_npub']}');
  }
  
  // Payment information
  if (values.containsKey('fiat_amount') && values.containsKey('fiat_code')) {
    details.add('${localizations.notificationAmount}: ${values['fiat_amount']} ${values['fiat_code']}');
  }
  
  if (values.containsKey('payment_method') && values['payment_method'] != null) {
    details.add('${localizations.notificationPaymentMethod}: ${values['payment_method']}');
  }
  
  // Expiration information
  if (values.containsKey('expiration_seconds')) {
    final seconds = values['expiration_seconds'];
    final minutes = seconds ~/ 60;
    details.add('${localizations.notificationExpiresIn}: ${minutes}m ${seconds % 60}s');
  }
  
  // Lightning amount
  if (values.containsKey('amount_msat')) {
    final msat = values['amount_msat'];
    final sats = msat ~/ 1000;
    details.add('${localizations.notificationAmount}: $sats sats');
  }
  
  // Payment retry information  
  if (values.containsKey('payment_attempts') && values['payment_attempts'] != null) {
    details.add('${localizations.notificationAttempts}: ${values['payment_attempts']}');
  }
  
  if (values.containsKey('payment_retries_interval') && values['payment_retries_interval'] != null) {
    details.add('${localizations.notificationRetryInterval}: ${values['payment_retries_interval']}s');
  }
  
  // Dispute information
  if (values.containsKey('user_token') && values['user_token'] != null) {
    details.add('${localizations.notificationToken}: ${values['user_token']}');
  }
  
  // Other information
  if (values.containsKey('reason')) {
    details.add('${localizations.notificationReason}: ${values['reason']}');
  }
  
  if (values.containsKey('rate')) {
    details.add('${localizations.notificationRate}: ${values['rate']}/5');
  }
  
  return details.isNotEmpty ? details.join('\n') : null;
}


Future<void> retryNotification(NostrEvent event, {int maxAttempts = 3}) async {
  int attempt = 0;
  bool success = false;

  while (!success && attempt < maxAttempts) {
    try {
      await showLocalNotification(event);
      success = true;
    } catch (e) {
      attempt++;
      if (attempt >= maxAttempts) {
        Logger().e('Failed to show notification after $maxAttempts attempts: $e');
        break;
      }

      // Exponential backoff: 1s, 2s, 4s, etc.
      final backoffSeconds = pow(2, attempt - 1).toInt();
      Logger().e('Notification attempt $attempt failed: $e. Retrying in ${backoffSeconds}s');
      await Future.delayed(Duration(seconds: backoffSeconds));
    }
  }
}

/// Fetch and process all new events from relays (Silent Push approach)
///
/// This function is called from the FCM silent push handler to fetch
/// all new events from relays and process notifications.
///
/// Flow:
/// 1. Load all active sessions from database
/// 2. Get last processed timestamp from storage
/// 3. Fetch all new events since last timestamp
/// 4. Process each event and show notifications
/// 5. Update last processed timestamp
///
/// Privacy: FCM doesn't contain any event data, only wakes up the app
Future<void> fetchAndProcessNewEvents({required List<String> relays}) async {
  final logger = Logger();

  try {
    logger.i('Starting to fetch new events from relays');

    // Step 1: Load all sessions from database
    final sessions = await _loadSessionsFromDatabase();

    if (sessions.isEmpty) {
      logger.i('No active sessions found');
      return;
    }

    logger.i('Found ${sessions.length} active sessions');

    // Step 2: Get last processed timestamp
    final sharedPrefs = SharedPreferencesAsync();
    final lastProcessedTime = await sharedPrefs.getInt('fcm.last_processed_timestamp') ?? 0;
    final since = DateTime.fromMillisecondsSinceEpoch(lastProcessedTime * 1000);

    logger.i('Fetching events since: ${since.toIso8601String()}');

    // Step 3: Initialize NostrService
    final nostrService = NostrService();
    final settings = Settings(
      relays: relays,
      fullPrivacyMode: false,
      mostroPublicKey: '', // Not needed for fetching
    );

    try {
      await nostrService.init(settings);
    } catch (e) {
      logger.e('Failed to initialize NostrService: $e');
      return;
    }

    // Step 4: Fetch new events for each session
    int processedCount = 0;
    final now = DateTime.now();

    for (final session in sessions) {
      try {
        // Create filter for this session's events
        // Use 'p' tag to filter by recipient (the trade key that can decrypt the event)
        // Note: 'authors' would filter by sender, but we need events sent TO this trade key
        final filter = NostrFilter(
          kinds: [1059], // Gift-wrapped events
          p: [session.tradeKey.public], // Events sent to this trade key
          since: since,
        );

        logger.d('Fetching events for session: ${session.orderId}');

        // Fetch events
        final events = await nostrService.fetchEvents(filter);

        logger.d('Found ${events.length} events for session ${session.orderId}');

        // Process each event
        for (final event in events) {
          final nostrEvent = NostrEvent(
            id: event.id,
            kind: event.kind,
            content: event.content,
            tags: event.tags,
            createdAt: event.createdAt,
            pubkey: event.pubkey,
            sig: event.sig,
            subscriptionId: event.subscriptionId,
          );

          // Show notification
          await showLocalNotification(nostrEvent);
          processedCount++;
        }
      } catch (e) {
        logger.e('Error processing events for session ${session.orderId}: $e');
        // Continue with next session
      }
    }

    // Step 5: Update last processed timestamp
    final newTimestamp = (now.millisecondsSinceEpoch / 1000).floor();
    await sharedPrefs.setInt('fcm.last_processed_timestamp', newTimestamp);

    logger.i('Processed $processedCount new events successfully');

  } catch (e, stackTrace) {
    logger.e('Error fetching and processing new events: $e');
    logger.e('Stack trace: $stackTrace');
  }
}

/// Process FCM notification from background when app is terminated (Legacy approach)
///
/// This function is kept for backward compatibility but is no longer used
/// in the Silent Push approach.
///
/// Parameters:
/// - [eventId]: The Nostr event ID from the FCM payload
/// - [recipientPubkey]: The recipient public key (trade key) from the FCM payload
/// - [relays]: List of relay URLs to fetch the event from
@Deprecated('Use fetchAndProcessNewEvents for Silent Push approach')
Future<void> processFCMBackgroundNotification({
  required String eventId,
  required String recipientPubkey,
  required List<String> relays,
}) async {
  final logger = Logger();

  try {
    logger.i('Processing FCM background notification for event: $eventId');

    // Step 1: Load sessions from database to find the matching session
    final sessions = await _loadSessionsFromDatabase();
    final matchingSession = sessions.cast<Session?>().firstWhere(
      (s) => s?.tradeKey.public == recipientPubkey,
      orElse: () => null,
    );

    if (matchingSession == null) {
      logger.w('No matching session found for recipient: ${recipientPubkey.substring(0, 16)}...');
      return;
    }

    logger.i('Found matching session for order: ${matchingSession.orderId}');

    // Step 2: Initialize NostrService with relay list
    final nostrService = NostrService();
    final settings = Settings(
      relays: relays,
      fullPrivacyMode: false,
      mostroPublicKey: '', // Not needed for just fetching events
    );

    try {
      await nostrService.init(settings);
      logger.i('NostrService initialized with ${relays.length} relays');
    } catch (e) {
      logger.e('Failed to initialize NostrService: $e');
      return;
    }

    // Step 3: Create filter to fetch the specific event by ID
    final filter = NostrFilter(
      ids: [eventId],
      kinds: [1059], // Gift-wrapped events
    );

    logger.i('Fetching event $eventId from relays...');

    // Step 4: Fetch the event from relays
    final events = await nostrService.fetchEvents(filter);

    if (events.isEmpty) {
      logger.w('Event $eventId not found in any relay');
      return;
    }

    logger.i('Found event ${events.first.id}, processing notification...');

    // Step 5: Convert to NostrEvent and process through existing notification system
    final nostrEvent = NostrEvent(
      id: events.first.id,
      kind: events.first.kind,
      content: events.first.content,
      tags: events.first.tags,
      createdAt: events.first.createdAt,
      pubkey: events.first.pubkey,
      sig: events.first.sig,
      subscriptionId: events.first.subscriptionId,
    );

    // Process and show the notification
    await showLocalNotification(nostrEvent);

    logger.i('FCM background notification processed and shown successfully');

  } catch (e, stackTrace) {
    logger.e('Error processing FCM background notification: $e');
    logger.e('Stack trace: $stackTrace');
  }
}  