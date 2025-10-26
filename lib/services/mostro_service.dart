import 'dart:async';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:dart_nostr/dart_nostr.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager_provider.dart';
import 'package:mostro_mobile/shared/providers.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/services/restore_service.dart';
import 'package:mostro_mobile/services/last_trade_index_service.dart';

class MostroService {
  final Ref ref;
  final _logger = Logger();

  Settings _settings;
  StreamSubscription<NostrEvent>? _ordersSubscription;
  StreamSubscription<NostrEvent>? _adminSubscription;

  MostroService(this.ref) : _settings = ref.read(settingsProvider);

  void init() {
    // Subscribe to the orders stream from SubscriptionManager
    // The SubscriptionManager will automatically manage subscriptions based on SessionNotifier changes
    _ordersSubscription = ref.read(subscriptionManagerProvider).orders.listen(
      _onOrderData,
      onError: (error, stackTrace) {
        _logger.e('Error in orders subscription',
            error: error, stackTrace: stackTrace);
      },
      cancelOnError: false,
    );

    // Subscribe to the admin stream for administrative messages (restore, last-trade-index)
    _adminSubscription = ref.read(subscriptionManagerProvider).admin.listen(
      _onAdminData,
      onError: (error, stackTrace) {
        _logger.e('Error in admin subscription',
            error: error, stackTrace: stackTrace);
      },
      cancelOnError: false,
    );
  }

  void dispose() {
    _ordersSubscription?.cancel();
    _adminSubscription?.cancel();
    _logger.i('MostroService disposed');
  }

  Future<void> _onAdminData(NostrEvent event) async {
    final eventStore = ref.read(eventStorageProvider);

    if (await eventStore.hasItem(event.id!)) return;
    await eventStore.putItem(
      event.id!,
      {
        'id': event.id,
        'created_at': event.createdAt!.millisecondsSinceEpoch ~/ 1000,
      },
    );

    // Admin messages are encrypted with master key
    final masterKey = ref.read(keyManagerProvider).masterKeyPair;
    if (masterKey == null) {
      _logger.w('Cannot decrypt admin message: no master key');
      return;
    }

    try {
      final decryptedEvent = await event.unWrap(masterKey.private);
      if (decryptedEvent.content == null) return;

      final result = jsonDecode(decryptedEvent.content!);

      if (result is! List || result.isEmpty) {
        _logger.w('Received empty or invalid admin payload, skipping');
        return;
      }

      // Handle restore messages (restore-session, last-trade-index)
      if (result[0] is Map && (result[0] as Map).containsKey('restore')) {
        final data = result[0] as Map<String, dynamic>;
        final restore = data['restore'] as Map<String, dynamic>;

        if (restore['action'] == 'restore-session') {
          final payload = restore['payload'] as Map<String, dynamic>?;
          if (payload != null) {
            await ref.read(restoreServiceProvider).processRestoreData(payload);
          }
        } else if (restore['action'] == 'last-trade-index') {
          final tradeIndex = restore['trade_index'] as int?;
          if (tradeIndex != null) {
            await ref.read(lastTradeIndexServiceProvider).processLastTradeIndex(tradeIndex);
          }
        }
        return;
      }

      // Handle batch orders response
      if (result[0] is Map && (result[0] as Map).containsKey('order')) {
        final data = result[0] as Map<String, dynamic>;
        final order = data['order'] as Map<String, dynamic>;

        if (order['action'] == 'orders') {
          final payload = order['payload'] as Map<String, dynamic>?;
          final orders = payload?['orders'] as List<dynamic>? ?? [];
          _logger.i('Received details for ${orders.length} orders');

          await ref.read(restoreServiceProvider).processOrderDetails(orders);
          return;
        }
      }

      _logger.w('Received unknown admin message type');
    } catch (e) {
      _logger.e('Error processing admin event', error: e);
    }
  }

  Future<void> _onOrderData(NostrEvent event) async {
    final eventStore = ref.read(eventStorageProvider);

    if (await eventStore.hasItem(event.id!)) return;
    await eventStore.putItem(
      event.id!,
      {
        'id': event.id,
        'created_at': event.createdAt!.millisecondsSinceEpoch ~/ 1000,
      },
    );

    final sessions = ref.read(sessionNotifierProvider);
    final matchingSession = sessions.firstWhereOrNull(
      (s) => s.tradeKey.public == event.recipient,
    );
    if (matchingSession == null) {
      _logger.w('No matching session found for recipient: ${event.recipient}');
      return;
    }
    final privateKey = matchingSession.tradeKey.private;

    try {
      final decryptedEvent = await event.unWrap(privateKey);
      if (decryptedEvent.content == null) return;

      final result = jsonDecode(decryptedEvent.content!);

      if (result is! List || result.isEmpty) {
        _logger.w('Received empty or invalid payload, skipping');
        return;
      }

      if (result[0] is Map && (result[0] as Map).containsKey('dm')) {
        _logger.i('Skipping dispute chat message (handled by DisputeChatNotifier)');
        return;
      }

      final msg = MostroMessage.fromJson(result[0]);
      final messageStorage = ref.read(mostroStorageProvider);

      final messageKey = decryptedEvent.id ?? event.id ?? 'msg_${DateTime.now().millisecondsSinceEpoch}';
      await messageStorage.addMessage(messageKey, msg);
      _logger.i(
        'Received DM, Event ID: ${decryptedEvent.id ?? event.id} with payload: ${decryptedEvent.content}',
      );

      await _maybeLinkChildOrder(msg, matchingSession);
    } catch (e) {
      _logger.e('Error processing order event', error: e);
    }
  }

  Future<void> _maybeLinkChildOrder(
    MostroMessage message,
    Session session,
  ) async {
    if (message.action != Action.newOrder || message.id == null) {
      return;
    }

    if (session.orderId != null || session.parentOrderId == null) {
      return;
    }

    final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
    await sessionNotifier.linkChildSessionToOrderId(
      message.id!,
      session.tradeKey.public,
    );

    ref.read(orderNotifierProvider(message.id!).notifier).subscribe();

    _logger.i(
      'Linked child order ${message.id} to parent ${session.parentOrderId}',
    );
  }

  Future<void> submitOrder(MostroMessage order) async {
    await publishOrder(order);
  }

  Future<void> takeBuyOrder(String orderId, int? amount) async {
    final amt = amount != null ? Amount(amount: amount) : null;
    await publishOrder(
      MostroMessage(
        action: Action.takeBuy,
        id: orderId,
        payload: amt,
      ),
    );
  }

  Future<void> takeSellOrder(
      String orderId, int? amount, String? lnAddress) async {
    final payload = lnAddress != null
        ? PaymentRequest(
            order: null,
            lnInvoice: lnAddress,
            amount: amount,
          )
        : amount != null
            ? Amount(amount: amount)
            : null;

    await publishOrder(
      MostroMessage(
        action: Action.takeSell,
        id: orderId,
        payload: payload,
      ),
    );
  }

  Future<void> sendInvoice(String orderId, String invoice, int? amount) async {
    final payload = PaymentRequest(
      order: null,
      lnInvoice: invoice,
      amount: amount,
    );
    await publishOrder(
      MostroMessage(
        action: Action.addInvoice,
        id: orderId,
        payload: payload,
      ),
    );
  }

  Future<void> cancelOrder(String orderId) async {
    await publishOrder(
      MostroMessage(
        action: Action.cancel,
        id: orderId,
      ),
    );
  }

  Future<void> sendFiatSent(String orderId) async {
    final payload = await _prepareChildOrderIfNeeded(
      orderId,
      callerLabel: 'fiatSent',
    );

    await publishOrder(
      MostroMessage(
        action: Action.fiatSent,
        id: orderId,
        payload: payload,
      ),
    );
  }

  Future<void> releaseOrder(String orderId) async {
    final payload = await _prepareChildOrderIfNeeded(
      orderId,
      callerLabel: 'release',
    );

    await publishOrder(
      MostroMessage(
        action: Action.release,
        id: orderId,
        payload: payload,
      ),
    );
  }

  Future<Payload?> _prepareChildOrderIfNeeded(
    String orderId, {
    required String callerLabel,
  }) async {
    final order = ref.read(orderNotifierProvider(orderId)).order;
    if (order?.minAmount == null ||
        order?.maxAmount == null ||
        order!.minAmount! >= order.maxAmount!) {
      return null;
    }

    final minAmount = order.minAmount!;
    final maxAmount = order.maxAmount!;
    final selectedAmount = order.fiatAmount;
    final remaining = maxAmount - selectedAmount;

    if (remaining < minAmount) {
      _logger.i(
        '[$callerLabel] Range order $orderId exhausted (remaining $remaining < min $minAmount); skipping child preparation.',
      );
      return null;
    }

    final keyManager = ref.read(keyManagerProvider);
    final nextKeyIndex = await keyManager.getNextKeyIndex();
    final nextTradeKey = await keyManager.deriveTradeKeyFromIndex(nextKeyIndex);

    final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
    final currentSession = sessionNotifier.getSessionByOrderId(orderId);
    if (currentSession != null && currentSession.role != null) {
      await sessionNotifier.createChildOrderSession(
        tradeKey: nextTradeKey,
        keyIndex: nextKeyIndex,
        parentOrderId: orderId,
        role: currentSession.role!,
      );
      _logger.i(
        '[$callerLabel] Prepared child session for $orderId using key index $nextKeyIndex',
      );
    } else {
      _logger.w(
        '[$callerLabel] Unable to prepare child session for $orderId; session or role missing.',
      );
    }

    return NextTrade(
      key: nextTradeKey.public,
      index: nextKeyIndex,
    );
  }

  Future<void> disputeOrder(String orderId) async {
    await publishOrder(
      MostroMessage(
        action: Action.dispute,
        id: orderId,
      ),
    );
  }

  Future<void> submitRating(String orderId, int rating) async {
    await publishOrder(
      MostroMessage(
        action: Action.rateUser,
        id: orderId,
        payload: RatingUser(userRating: rating),
      ),
    );
  }

  Future<void> publishOrder(MostroMessage order) async {
    final session = await _getSession(order);

    final event = await order.wrap(
      tradeKey: session.tradeKey,
      recipientPubKey: _settings.mostroPublicKey,
      masterKey: session.fullPrivacy ? null : session.masterKey,
      keyIndex: session.fullPrivacy ? null : session.keyIndex,
    );
    _logger
        .i('Sending DM, Event ID: ${event.id} with payload: ${order.toJson()}');
    await ref.read(nostrServiceProvider).publishEvent(event);
  }

  Future<Session> _getSession(MostroMessage order) async {
    final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
    if (order.requestId != null) {
      final session = sessionNotifier.getSessionByRequestId(order.requestId!);
      if (session == null) {
        throw Exception('No session found for requestId: ${order.requestId}');
      }
      return session;
    } else if (order.id != null) {
      final session = sessionNotifier.getSessionByOrderId(order.id!);
      if (session == null) {
        throw Exception('No session found for orderId: ${order.id}');
      }
      return session;
    }
    throw Exception('Order has neither requestId nor orderId');
  }

  void updateSettings(Settings settings) {
    _settings = settings.copyWith();
  }
}
