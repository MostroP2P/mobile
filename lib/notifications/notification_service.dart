import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/cant_do.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/payment_request.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initializeNotifications() async {
  const android = AndroidInitializationSettings(
    '@drawable/ic_bg_service_small',
  );
  const ios = DarwinInitializationSettings();

  const linux = LinuxInitializationSettings(
    defaultActionName: 'Open',
  );

  const initSettings = InitializationSettings(
      android: android, iOS: ios, linux: linux, macOS: ios);
  await flutterLocalNotificationsPlugin.initialize(initSettings);
}

Future<void> showLocalNotification(NostrEvent event, WidgetRef ref) async {
  await _showLocalNotificationInternal(event, ref);
}

/// Overload for services that use Ref instead of WidgetRef
Future<void> showLocalNotificationFromService(NostrEvent event, Ref ref) async {
  await _showLocalNotificationInternal(event, ref);
}

Future<void> _showLocalNotificationInternal(
    NostrEvent event, dynamic ref) async {
  // Only process kind 1059 events
  if (event.kind != 1059) {
    return;
  }

  try {
    // 1. Find the session with matching trade key
    final sessions = ref.read(sessionNotifierProvider);
    final session = _findSessionForEvent(event, sessions);

    if (session == null) {
      // Fallback to generic message if no session found
      await _showGenericNotification(event);
      return;
    }

    // 2. Decrypt the event content
    final decryptedEvent = await event.unWrap(session.tradeKey.private);

    if (decryptedEvent.content == null || decryptedEvent.content!.isEmpty) {
      await _showGenericNotification(event);
      return;
    }

    // 3. Parse MostroMessage from decrypted content
    final result = jsonDecode(decryptedEvent.content!);
    if (result is! List || result.isEmpty) {
      await _showGenericNotification(event);
      return;
    }

    final msg = MostroMessage.fromJson(result[0]);

    // 4. Generate action-specific notification
    await _showActionBasedNotification(event, msg, session);
  } catch (e) {
    Logger().e('Failed to decrypt notification: $e');
    await _showGenericNotification(event);
  }
}

Future<void> retryNotification(NostrEvent event, WidgetRef ref,
    {int maxAttempts = 3}) async {
  int attempt = 0;
  bool success = false;

  while (!success && attempt < maxAttempts) {
    try {
      await showLocalNotification(event, ref);
      success = true;
    } catch (e) {
      attempt++;
      if (attempt >= maxAttempts) {
        Logger()
            .e('Failed to show notification after $maxAttempts attempts: $e');
        break;
      }

      // Exponential backoff: 1s, 2s, 4s, etc.
      final backoffSeconds = pow(2, attempt - 1).toInt();
      Logger().e(
          'Notification attempt $attempt failed: $e. Retrying in ${backoffSeconds}s');
      await Future.delayed(Duration(seconds: backoffSeconds));
    }
  }

  // Optionally store failed notifications for later retry when app returns to foreground
  if (!success) {
    // Store the event ID in a persistent queue for later retry
    await FailedNotificationQueue.add(event.id!);
  }
}

class FailedNotificationQueue {
  static const String _queueKey = 'failed_notifications';

  static Future<void> add(String eventId) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_queueKey) ?? [];
    if (!queue.contains(eventId)) {
      queue.add(eventId);
      await prefs.setStringList(_queueKey, queue);
    }
  }

  static Future<List<String>> getAndClear() async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_queueKey) ?? [];
    await prefs.remove(_queueKey);
    return queue;
  }
}

/// Find session that matches the event's target public key
Session? _findSessionForEvent(NostrEvent event, List<Session> sessions) {
  // Find session where event is addressed to session's trade key public key
  final targetPubkey = event.tags
      ?.firstWhere((tag) => tag[0] == 'p', orElse: () => [])
      .elementAtOrNull(1);

  if (targetPubkey == null) return null;

  try {
    return sessions.firstWhere(
      (session) => session.tradeKey.public == targetPubkey,
    );
  } catch (e) {
    return null;
  }
}

/// Show generic notification when decryption fails or no session found
Future<void> _showGenericNotification(NostrEvent event) async {
  final payloadData = {
    'eventId': event.id ?? '',
    'kind': event.kind.toString(),
  };

  // Get current locale
  final locale = ui.PlatformDispatcher.instance.locale;
  final S localizations = await S.delegate.load(locale);

  final details = NotificationDetails(
    android: AndroidNotificationDetails(
      'mostro_channel',
      localizations.notificationChannelName,
      channelDescription: localizations.notificationChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      visibility: NotificationVisibility.public,
      playSound: true,
      enableVibration: true,
      ticker: 'ticker',
      icon: '@drawable/ic_notification',
      styleInformation: BigTextStyleInformation(
        localizations.notificationNewEncryptedMessage,
        htmlFormatBigText: false,
        contentTitle: localizations.notificationNewMostroMessage,
        htmlFormatContentTitle: false,
      ),
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    ),
  );

  await flutterLocalNotificationsPlugin.show(
    event.id.hashCode,
    localizations.notificationNewMostroMessage,
    localizations.notificationNewEncryptedMessage,
    details,
    payload: jsonEncode(payloadData),
  );
}

/// Show action-based notification with specific message content
Future<void> _showActionBasedNotification(
    NostrEvent event, MostroMessage msg, Session session) async {
  // Get current locale
  final locale = ui.PlatformDispatcher.instance.locale;
  final S localizations = await S.delegate.load(locale);

  final title = _getActionTitle(msg.action, localizations);
  final message =
      _getActionBasedMessage(msg.action, msg, session, localizations);

  final payloadData = {
    'eventId': event.id ?? '',
    'kind': event.kind.toString(),
    'orderId': msg.id ?? session.orderId,
    'action': msg.action.value,
  };

  final details = NotificationDetails(
    android: AndroidNotificationDetails(
      'mostro_channel',
      localizations.notificationChannelName,
      channelDescription: localizations.notificationChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      visibility: NotificationVisibility.public,
      playSound: true,
      enableVibration: true,
      ticker: 'ticker',
      icon: '@drawable/ic_notification',
      styleInformation: BigTextStyleInformation(
        message,
        htmlFormatBigText: false,
        contentTitle: title,
        htmlFormatContentTitle: false,
      ),
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    ),
  );

  await flutterLocalNotificationsPlugin.show(
    event.id.hashCode,
    title,
    message,
    details,
    payload: jsonEncode(payloadData),
  );
}

/// Get notification title based on action
String _getActionTitle(Action action, S localizations) {
  switch (action) {
    case Action.newOrder:
      return localizations.notificationOrderPublished;
    case Action.takeBuy:
    case Action.takeSell:
    case Action.buyerTookOrder:
      return localizations.notificationOrderTaken;
    case Action.payInvoice:
      return localizations.notificationPaymentRequired;
    case Action.addInvoice:
    case Action.waitingBuyerInvoice:
      return localizations.notificationInvoiceRequired;
    case Action.fiatSent:
    case Action.fiatSentOk:
      return localizations.notificationPaymentSent;
    case Action.release:
    case Action.released:
      return localizations.notificationBitcoinReleased;
    case Action.cancel:
    case Action.canceled:
      return localizations.notificationOrderCanceled;
    case Action.disputeInitiatedByYou:
    case Action.disputeInitiatedByPeer:
      return localizations.notificationDisputeStarted;
    case Action.purchaseCompleted:
      return localizations.notificationTradeComplete;
    case Action.paymentFailed:
      return localizations.notificationPaymentFailed;
    case Action.cantDo:
      return localizations.notificationRequestFailed;
    case Action.cooperativeCancelInitiatedByPeer:
      return localizations.notificationCooperativeCancelInitiatedByPeer;
    case Action.cooperativeCancelInitiatedByYou:
      return localizations.notificationCooperativeCancelInitiatedByYou;
    case Action.cooperativeCancelAccepted:
      return localizations.notificationCooperativeCancelAccepted;
    default:
      return localizations.notificationMostroUpdate;
  }
}

/// Get action-based message content following Mostro protocol suggestions
String _getActionBasedMessage(
    Action action, MostroMessage msg, Session session, S localizations) {
  switch (action) {
    case Action.newOrder:
      return localizations.notificationOrderPublishedBody;

    case Action.takeBuy:
    case Action.takeSell:
    case Action.buyerTookOrder:
      return localizations.notificationOrderTakenMessage;

    case Action.payInvoice:
      // Extract amount and fiat info from PaymentRequest payload
      if (msg.payload is PaymentRequest) {
        final paymentRequest = msg.payload as PaymentRequest;
        final order = paymentRequest.order;
        // Try to get amount from PaymentRequest first, then from Order if available
        final amount = paymentRequest.amount != null && paymentRequest.amount! > 0 
            ? paymentRequest.amount! 
            : (order?.amount ?? 0);
        final fiatCode = order?.fiatCode ?? 'USD';
        final fiatAmount = order?.fiatAmount ?? 0;
        return localizations.payInvoice(
            amount.toString(), 15, fiatAmount.toString(), fiatCode);
      }
      return localizations.payInvoiceGeneric;

    case Action.addInvoice:
    case Action.waitingBuyerInvoice:
      // Extract amount and fiat info from Order payload
      if (msg.payload is Order) {
        final order = msg.payload as Order;
        final amount = order.amount;
        final fiatCode = order.fiatCode;
        final fiatAmount = order.fiatAmount;
        return localizations.addInvoice(
            amount.toString(), 15, fiatAmount.toString(), fiatCode);
      }
      return localizations.addInvoiceGeneric;

    case Action.fiatSent:
    case Action.fiatSentOk:
      return localizations.notificationPaymentSentMessage;

    case Action.release:
    case Action.released:
      return localizations.notificationBitcoinReleased;

    case Action.cancel:
    case Action.canceled:
      return localizations.notificationOrderCanceled;

    case Action.cooperativeCancelInitiatedByPeer:
      return localizations
          .cooperativeCancelInitiatedByPeer(session.orderId ?? '');

    case Action.disputeInitiatedByYou:
      return localizations.disputeInitiatedByYou(session.orderId ?? '', '');

    case Action.disputeInitiatedByPeer:
      return localizations.disputeInitiatedByPeer(session.orderId ?? '', '');

    case Action.purchaseCompleted:
      return localizations.purchaseCompleted;

    case Action.paymentFailed:
      return localizations.paymentFailed(3, 5);

    case Action.cantDo:
      // Extract reason from CantDo payload
      if (msg.payload is CantDo) {
        final reason = (msg.payload as CantDo).cantDoReason.toString();
        return localizations.notificationUnableToProcessReasonMessage(reason);
      }
      return localizations.notificationUnableToProcessMessage;

    default:
      return '';
  }
}

/// Simple notification function for background services without Riverpod context
Future<void> showSimpleNotification(NostrEvent event) async {
  // Only process kind 1059 events
  if (event.kind != 1059) {
    return;
  }

  await _showGenericNotification(event);
}
