import 'dart:async';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:dart_nostr/dart_nostr.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager_provider.dart';
import 'package:mostro_mobile/shared/providers.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';

class MostroService {
  final Ref ref;
  final _logger = Logger();

  Settings _settings;
  StreamSubscription<NostrEvent>? _ordersSubscription;

  MostroService(this.ref) : _settings = ref.read(settingsProvider);

  void init() {
    // Subscribe to the orders stream from SubscriptionManager
    // The SubscriptionManager will automatically manage subscriptions based on SessionNotifier changes
    _ordersSubscription = ref.read(subscriptionManagerProvider).orders.listen(
      _onData,
      onError: (error, stackTrace) {
        logger.e('Error in orders subscription',
            error: error, stackTrace: stackTrace);
      },
      cancelOnError: false,
    );
  }

  void dispose() {
    _ordersSubscription?.cancel();
    logger.i('MostroService disposed');
  }
  
  //IMPORTANT : The app always use trade index 1 for restore-related messages
  // When subscribtions are created from restore process for real orders, restore related messages may be avoided
  bool _isRestorePayload(Map<String, dynamic> json) {
    // Check if this is a restore-specific payload that should be ignored
    // These payloads are only used during restore process via temporary trade key

    // Safely get wrapper and validate it's a Map
    final wrapper = json['restore'] ?? json['order'];
    if (wrapper == null) return false;
    if (wrapper is! Map<String, dynamic>) return false;

    // Safely get payload and validate it's a Map
    final payloadValue = wrapper['payload'];
    if (payloadValue == null) return false;
    if (payloadValue is! Map<String, dynamic>) return false;

    final payload = payloadValue;

    // RestoreData: has 'restore_data' wrapper with 'orders' and 'disputes' arrays
    if (payload.containsKey('restore_data')) {
      return true;
    }

    // LastTradeIndexResponse: has 'trade_index' field
    if (payload.containsKey('trade_index')) {
      return true;
    }

    // OrdersResponse: has 'orders' array with OrderDetail objects
    // OrderDetail has buyer_trade_pubkey/seller_trade_pubkey fields
    if (payload.containsKey('orders')) {
      final ordersValue = payload['orders'];

      // Validate orders is a List
      if (ordersValue is! List) return false;

      // Check first element if list is not empty
      if (ordersValue.isNotEmpty) {
        final firstOrderValue = ordersValue[0];

        // Validate first element is a Map
        if (firstOrderValue is! Map<String, dynamic>) return false;

        // Check for restore-specific fields
        if (firstOrderValue.containsKey('buyer_trade_pubkey') ||
            firstOrderValue.containsKey('seller_trade_pubkey')) {
          return true;
        }
      }
    }

    return false;
  }

  Future<void> _onData(NostrEvent event) async {
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
      logger.w('No matching session found for recipient: ${event.recipient}');
      return;
    }
    final privateKey = matchingSession.tradeKey.private;

    try {
      final decryptedEvent = await event.unWrap(privateKey);

      if (decryptedEvent.content == null) return;

      final result = jsonDecode(decryptedEvent.content!);
      
      // Ensure result is a non-empty List before accessing elements
      if (result is! List || result.isEmpty) {
        logger.w('Received empty or invalid payload, skipping');
        return;
      }

      // Skip dispute chat messages (they have "dm" key and are handled by DisputeChatNotifier)
      if (result[0] is Map && (result[0] as Map).containsKey('dm')) {
        logger.i('Skipping dispute chat message (handled by DisputeChatNotifier)');
        return;
      }

      // Skip restore-specific payloads that arrive as historical events due to temporary subscription
      if (result[0] is Map && _isRestorePayload(result[0] as Map<String, dynamic>)) {
        return;
      }

      final msg = MostroMessage.fromJson(result[0]);

      final messageStorage = ref.read(mostroStorageProvider);
      
      // Use decryptedEvent.id if available, otherwise fall back to original event.id
      // This handles cases where admin messages might not have an id in the decrypted event
      final messageKey = decryptedEvent.id ?? event.id ?? 'msg_${DateTime.now().millisecondsSinceEpoch}';
      await messageStorage.addMessage(messageKey, msg);
      logger.i(
        'Received DM, Event ID: ${decryptedEvent.id ?? event.id} with payload: ${decryptedEvent.content}',
      );

      await _maybeLinkChildOrder(msg, matchingSession);
    } catch (e) {
      logger.e('Error processing event', error: e);
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

    logger.i(
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
      logger.i(
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
      logger.i(
        '[$callerLabel] Prepared child session for $orderId using key index $nextKeyIndex',
      );
    } else {
      logger.w(
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
