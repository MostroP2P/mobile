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

class MostroService {
  final Ref ref;
  final _logger = Logger();

  Settings _settings;
  StreamSubscription<NostrEvent>? _ordersSubscription;
  StreamSubscription<NostrEvent>? _masterKeySubscription;

  final Map<String, Completer<Order>> _orderDetailCompleters = {};

  MostroService(this.ref) : _settings = ref.read(settingsProvider);

  void init() {
    // Subscribe to the orders stream from SubscriptionManager
    // The SubscriptionManager will automatically manage subscriptions based on SessionNotifier changes
    _ordersSubscription = ref.read(subscriptionManagerProvider).orders.listen(
      _onData,
      onError: (error, stackTrace) {
        _logger.e('Error in orders subscription',
            error: error, stackTrace: stackTrace);
      },
      cancelOnError: false,
    );

    // Subscribe to master key messages for restore session responses
    _masterKeySubscription = ref.read(subscriptionManagerProvider).masterKey.listen(
      _onData,
      onError: (error, stackTrace) {
        _logger.e('Error in master key subscription',
            error: error, stackTrace: stackTrace);
      },
      cancelOnError: false,
    );
  }

  void dispose() {
    _ordersSubscription?.cancel();
    _masterKeySubscription?.cancel();
    _logger.i('MostroService disposed');
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
    Session? matchingSession = sessions.firstWhereOrNull(
      (s) => s.tradeKey.public == event.recipient,
    );

    String privateKey;
    if (matchingSession != null) {
      privateKey = matchingSession.tradeKey.private;
    } else {
      final keyManager = ref.read(keyManagerProvider);
      final masterKey = keyManager.masterKeyPair;
      if (masterKey != null && event.recipient != null && event.recipient == masterKey.public) {
        privateKey = masterKey.private;
      } else {
        _logger.w('No matching session found for recipient: ${event.recipient}');
        return;
      }
    }

    try {
      final decryptedEvent = await event.unWrap(privateKey);
      if (decryptedEvent.content == null) {
        _logger.w('Decrypted event has no content');
        return;
      }

      final result = jsonDecode(decryptedEvent.content!);
      if (result is! List) {
        _logger.w('Decoded result is not a List: ${result.runtimeType}');
        return;
      }

      final msg = MostroMessage.fromJson(result[0]);

      if (msg.action == Action.restoreSession) {
        await _handleRestoreResponse(msg);
        return;
      }

      if (msg.action == Action.orders) {
        await _handleOrdersResponse(msg);
        return;
      }

      if (matchingSession != null) {
        final messageStorage = ref.read(mostroStorageProvider);
        await messageStorage.addMessage(decryptedEvent.id!, msg);
        _logger.i(
          'Received DM, Event ID: ${decryptedEvent.id} with payload: ${decryptedEvent.content}',
        );

        await _maybeLinkChildOrder(msg, matchingSession);
      }
    } catch (e, stackTrace) {
      _logger.e('Error processing event', error: e, stackTrace: stackTrace);
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

  Future<void> requestRestoreSession() async {
    _logger.i('Requesting restore session from Mostro');

    final keyManager = ref.read(keyManagerProvider);
    final masterKey = keyManager.masterKeyPair!;

    final message = MostroMessage(
      action: Action.restoreSession,
    );

    final event = await message.wrap(
      tradeKey: masterKey,
      recipientPubKey: _settings.mostroPublicKey,
      masterKey: masterKey,
      keyIndex: null,
    );

    await ref.read(nostrServiceProvider).publishEvent(event);
  }

  Future<void> requestOrderDetails(List<String> orderIds) async {
    if (orderIds.isEmpty) {
      _logger.w('Cannot request order details with empty list');
      return;
    }

    final keyManager = ref.read(keyManagerProvider);
    final masterKey = keyManager.masterKeyPair!;

    const maxOrdersPerRequest = 20;
    for (var i = 0; i < orderIds.length; i += maxOrdersPerRequest) {
      final batch = orderIds.skip(i).take(maxOrdersPerRequest).toList();

      final message = MostroMessage(
        action: Action.orders,
        payload: OrdersRequest(ids: batch),
      );

      final event = await message.wrap(
        tradeKey: masterKey,
        recipientPubKey: _settings.mostroPublicKey,
        masterKey: masterKey,
        keyIndex: null,
      );

      await ref.read(nostrServiceProvider).publishEvent(event);
    }
  }

  Future<void> _handleRestoreResponse(MostroMessage message) async {
    try {
      if (message.payload == null) {
        _logger.w('Received empty restore response');
        return;
      }

      if (message.payload is! RestoreData) {
        _logger.w('Invalid restore payload type: ${message.payload.runtimeType}');
        return;
      }

      final restoreData = message.payload as RestoreData;

      if (restoreData.orders.isEmpty) {
        _logger.i('No orders to restore');
        return;
      }

      final keyManager = ref.read(keyManagerProvider);
      final masterKey = keyManager.masterKeyPair;
      if (masterKey == null) {
        _logger.e('No master key available for restore');
        return;
      }

      final orderIds = restoreData.orders.map((o) => o.orderId).toList();
      for (final orderId in orderIds) {
        _orderDetailCompleters[orderId] = Completer<Order>();
      }

      await requestOrderDetails(orderIds);

      final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
      int restoredCount = 0;
      int maxTradeIndex = 0;

      for (final orderInfo in restoreData.orders) {
        try {
          final completer = _orderDetailCompleters[orderInfo.orderId];
          if (completer == null) {
            _logger.w('No completer found for order ${orderInfo.orderId}');
            continue;
          }

          final orderDetails = await completer.future.timeout(
            Duration(seconds: 10),
            onTimeout: () {
              _logger.w('Timeout waiting for details of order ${orderInfo.orderId}');
              throw TimeoutException('Order details request timed out');
            },
          );

          final tradeKey = await keyManager.deriveTradeKeyFromIndex(orderInfo.tradeIndex);

          final Role role;
          if (orderDetails.buyerTradePubkey != null && orderDetails.buyerTradePubkey == tradeKey.public) {
            role = Role.buyer;
          } else if (orderDetails.sellerTradePubkey != null && orderDetails.sellerTradePubkey == tradeKey.public) {
            role = Role.seller;
          } else {
            _logger.w('Order ${orderInfo.orderId} does not belong to this user, skipping');
            continue;
          }

          final session = Session(
            masterKey: masterKey,
            tradeKey: tradeKey,
            keyIndex: orderInfo.tradeIndex,
            fullPrivacy: _settings.fullPrivacyMode,
            startTime: DateTime.now(),
            orderId: orderInfo.orderId,
            role: role,
          );

          await sessionNotifier.saveSession(session);
          restoredCount++;

          if (orderInfo.tradeIndex > maxTradeIndex) {
            maxTradeIndex = orderInfo.tradeIndex;
          }

          _logger.i('Restored order ${orderInfo.orderId} as ${role.value}');
          _orderDetailCompleters.remove(orderInfo.orderId);
        } catch (e) {
          _logger.e('Failed to restore order ${orderInfo.orderId}', error: e);
          _orderDetailCompleters.remove(orderInfo.orderId);
        }
      }

      _orderDetailCompleters.clear();

      if (restoredCount > 0) {
        await keyManager.setCurrentKeyIndex(maxTradeIndex + 1);
      }

      _logger.i(
        'Restored $restoredCount orders, ${restoreData.disputes.length} disputes'
      );
    } catch (e, stackTrace) {
      _logger.e('Failed to handle restore response', error: e, stackTrace: stackTrace);
      _orderDetailCompleters.clear();
    }
  }

  Future<void> _handleOrdersResponse(MostroMessage message) async {
    try {
      if (message.payload == null) {
        _logger.w('Received empty orders response');
        return;
      }

      if (message.payload is! OrdersResponse) {
        _logger.w('Invalid orders payload type: ${message.payload.runtimeType}');
        return;
      }

      final ordersResponse = message.payload as OrdersResponse;

      for (final order in ordersResponse.orders) {
        if (order.id != null) {
          final completer = _orderDetailCompleters[order.id!];
          if (completer != null && !completer.isCompleted) {
            completer.complete(order);
          }
        }
      }

      _logger.i('Completed ${ordersResponse.orders.length} order detail requests');
    } catch (e, stackTrace) {
      _logger.e('Failed to handle orders response', error: e, stackTrace: stackTrace);
    }
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
