import 'dart:convert';
import 'dart:math';

import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mostro_mobile/core/app.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/payment_failed.dart';
import 'package:mostro_mobile/data/models/peer.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as mostro_action;
import 'package:mostro_mobile/data/repositories/session_storage.dart';
import 'package:mostro_mobile/features/key_manager/key_derivator.dart';
import 'package:mostro_mobile/features/key_manager/key_manager.dart';
import 'package:mostro_mobile/features/key_manager/key_storage.dart';
import 'package:mostro_mobile/features/notifications/utils/notification_data_extractor.dart';
import 'package:mostro_mobile/features/notifications/utils/notification_message_mapper.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/generated/l10n_en.dart';
import 'package:mostro_mobile/generated/l10n_es.dart';
import 'package:mostro_mobile/generated/l10n_it.dart';
import 'package:mostro_mobile/shared/providers/legible_handle_provider.dart';
import 'package:mostro_mobile/background/background.dart' as bg;
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

Future<void> showLocalNotification(NostrEvent event) async {
  try {
    final mostroMessage = await _decryptAndProcessEvent(event);
    if (mostroMessage == null) return;
    

    final sessions = await _loadSessionsFromDatabase();
    final matchingSession = sessions.cast<Session?>().firstWhere(
      (session) => session?.orderId == mostroMessage.id,
      orElse: () => null,
    );
    
    final notificationData = await _extractNotificationDataWithContext(mostroMessage, matchingSession);
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

    await flutterLocalNotificationsPlugin.show(
      event.id.hashCode,
      notificationText.title,
      notificationText.body,
      details,
      payload: mostroMessage.id,
    );

    Logger().i('Shown: ${notificationText.title} - ${notificationText.body}');
  } catch (e) {
    Logger().e('Notification error: $e');
  }
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


// Extract notification data with enhanced context for background notifications
Future<NotificationData?> _extractNotificationDataWithContext(MostroMessage event, Session? session) async {
  Map<String, dynamic> values = {};
  
  switch (event.action) {
    case mostro_action.Action.buyerTookOrder:
      final order = event.getPayload<Order>();
      if (order == null) return null;
      
      // Get buyer nickname from database or use fallback
      values['buyer_npub'] = await _getNicknameFromDatabase(order.buyerTradePubkey) ?? 'Unknown';
      break;
      
    case mostro_action.Action.holdInvoicePaymentAccepted:
      final order = event.getPayload<Order>();
      if (order == null) return null;
      
      values = {
        'fiat_code': order.fiatCode,
        'fiat_amount': order.fiatAmount,
        'payment_method': order.paymentMethod,
      };
      
      if (order.sellerTradePubkey != null) {
        values['seller_npub'] = await _getNicknameFromDatabase(order.sellerTradePubkey) ?? 'Unknown';
      }
      break;
      
    case mostro_action.Action.holdInvoicePaymentSettled:
      final order = event.getPayload<Order>();
      if (order?.buyerTradePubkey != null) {
        values['buyer_npub'] = await _getNicknameFromDatabase(order!.buyerTradePubkey) ?? 'Unknown';
      }
      break;
      
    case mostro_action.Action.fiatSentOk:
      if (session?.role != Role.seller) return null;
      
      final peer = event.getPayload<Peer>();
      if (peer?.publicKey != null) {
        values['buyer_npub'] = await _getNicknameFromDatabase(peer!.publicKey) ?? 'Unknown';
      }
      break;
      
    case mostro_action.Action.released:
      final order = event.getPayload<Order>();
      if (order?.sellerTradePubkey != null) {
        values['seller_npub'] = await _getNicknameFromDatabase(order!.sellerTradePubkey) ?? 'Unknown';
      }
      break;
      
    case mostro_action.Action.waitingSellerToPay:
      values['expiration_seconds'] = Config.expirationSeconds;
      break;
      
    case mostro_action.Action.waitingBuyerInvoice:
      values['expiration_seconds'] = Config.expirationSeconds;
      break;
      
    case mostro_action.Action.paymentFailed:
      final paymentFailed = event.getPayload<PaymentFailed>();
      values = {
        'payment_attempts': paymentFailed?.paymentAttempts,
        'payment_retries_interval': paymentFailed?.paymentRetriesInterval,
      };
      break;
      
    case mostro_action.Action.disputeInitiatedByYou:
    case mostro_action.Action.disputeInitiatedByPeer:
      final dispute = event.getPayload<Dispute>();
      if (dispute == null) return null;
      values['user_token'] = dispute.disputeId;
      break;
      
    case mostro_action.Action.addInvoice:
      final order = event.getPayload<Order>();
      if (order?.status == Status.settledHoldInvoice) {
        final now = DateTime.now();
        values = {
          'fiat_amount': order?.fiatAmount,
          'fiat_code': order?.fiatCode,
          'failed_at': now.millisecondsSinceEpoch,
        };
      }
      break;
      
    case mostro_action.Action.cantDo:
    case mostro_action.Action.canceled:
      return null;
      
    default:
      return NotificationDataExtractor.extractFromMostroMessage(event, null);
  }
  
  return NotificationData(
    action: event.action,
    values: values,
    isTemporary: false,
  );
}

// Get nickname using the same deterministic method as foreground
Future<String?> _getNicknameFromDatabase(String? publicKey) async {
  if (publicKey == null) return null;
  try {
    return deterministicHandleFromHexKey(publicKey);
  } catch (e) {
    return 'unknown-user';
  }
}

// Get expanded text showing additional values
String? _getExpandedText(Map<String, dynamic> values) {
  if (values.isEmpty) return null;
  
  final List<String> details = [];
  
  if (values.containsKey('expiration_seconds')) {
    final seconds = values['expiration_seconds'];
    final minutes = seconds ~/ 60;
    details.add('Expires in: ${minutes}m ${seconds % 60}s');
  }
  
  if (values.containsKey('amount_msat')) {
    final msat = values['amount_msat'];
    final sats = msat ~/ 1000;
    details.add('Amount: $sats sats');
  }
  
  if (values.containsKey('reason')) {
    details.add('Reason: ${values['reason']}');
  }
  
  if (values.containsKey('rate')) {
    details.add('Rate: ${values['rate']}/5');
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