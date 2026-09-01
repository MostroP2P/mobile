import 'dart:async';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:dart_nostr/dart_nostr.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/services/chat_cursor_store.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager_provider.dart';
import 'package:mostro_mobile/shared/providers.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/features/mostro/mostro_instance.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

class MostroService {
  final Ref ref;

  Settings _settings;
  StreamSubscription<NostrEvent>? _ordersSubscription;

  MostroService(this.ref) : _settings = ref.read(settingsProvider);

  void init() {
    // Cancel any existing subscription to prevent leaks on re-init
    _ordersSubscription?.cancel();

    // Subscribe to the orders stream from SubscriptionManager
    // The SubscriptionManager will automatically manage subscriptions based on SessionNotifier changes
    _ordersSubscription = ref
        .read(subscriptionManagerProvider)
        .orders
        .listen(
          _onData,
          onError: (error, stackTrace) {
            logger.e(
              'Error in orders subscription',
              error: error,
              stackTrace: stackTrace,
            );
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

  /// Event ids currently inside [_onData], so copies of the same event racing
  /// in from several relays don't get processed twice while the durable
  /// marker below is not yet written.
  final Set<String> _inFlightEventIds = <String>{};

  /// Durably marks [event] as fully handled. Written only AFTER processing
  /// completes (or the event is conclusively not for this consumer): the
  /// background service suppresses its push notification for any id present
  /// in this store, and a reservation written *before* processing poisoned
  /// the event forever when the first attempt failed mid-way (session not
  /// loaded yet, decrypt error, process death between the reservation and the
  /// message write) — the daemon's message then never notified, was skipped
  /// by every later replay, and the order sat at a stale status across
  /// restarts.
  Future<void> _markEventProcessed(NostrEvent event) async {
    final eventId = event.id!;
    await ref.read(eventStorageProvider).putItem(eventId, {
      'id': eventId,
      'created_at': event.createdAt!.millisecondsSinceEpoch ~/ 1000,
    });
    // Only once the durable marker is written may the cursor move: a failed
    // putItem leaves the event unmarked, and a cursor advanced past it would
    // drop it from every later replay.
    _advanceOrdersCursor(event);
  }

  /// Events seen but deliberately left unmarked (no matching session yet, or
  /// a failure mid-processing), keyed by id. They still need replaying, so
  /// the shared node cursor must not move past the oldest of them.
  final Map<String, DateTime> _retryableEvents = <String, DateTime>{};

  /// How long an unmarked event holds the cursor back. Bounded so an event
  /// that can never be processed (a trade key whose session is gone) cannot
  /// freeze the cursor — and with it the replay window — forever.
  static const _retryHoldWindow = Duration(hours: 1);

  /// Records an event that was not marked processed, so [_advanceOrdersCursor]
  /// keeps the replay window covering it.
  void _holdEventForRetry(NostrEvent event) {
    if (event.kind != 14 || event.id == null || event.createdAt == null) return;
    _pruneExpiredHolds();
    _retryableEvents[event.id!] = event.createdAt!;
  }

  /// Drops holds older than [_retryHoldWindow]. Runs on both the hold and the
  /// advance path: pruning only when an event is accepted would let the map
  /// grow unpruned through a run in which every event is held.
  void _pruneExpiredHolds() {
    _retryableEvents.removeWhere(
      (_, at) => at.isBefore(DateTime.now().subtract(_retryHoldWindow)),
    );
  }

  /// Ids currently holding the cursor back.
  @visibleForTesting
  Set<String> get debugHeldEventIds => _retryableEvents.keys.toSet();

  /// Advances the orders `since` cursor for a processed event.
  ///
  /// Only kind 14 counts: the cursor feeds the NIP-44 filter, and gift wrap
  /// (1059) timestamps are randomized, so letting them move it would push
  /// `since` past kind-14 messages once the node switches transport.
  ///
  /// The cursor is a contiguous watermark: it never moves past an event still
  /// awaiting a retry, otherwise one trade's newer response would evict
  /// another trade's older, still-unprocessed one from the replay window.
  void _advanceOrdersCursor(NostrEvent event) {
    _retryableEvents.remove(event.id);
    if (event.kind != 14) return;
    final accepted = event.createdAt!;
    _pruneExpiredHolds();
    final blocked = _retryableEvents.values.any((at) => !at.isAfter(accepted));
    if (blocked) return;
    unawaited(
      ref
          .read(ordersCursorStoreProvider)
          .advance(_settings.mostroPublicKey, accepted),
    );
  }

  Future<void> _onData(NostrEvent event) async {
    final eventId = event.id!;
    if (!_inFlightEventIds.add(eventId)) return;
    try {
      await _processEvent(event);
    } finally {
      _inFlightEventIds.remove(eventId);
    }
  }

  Future<void> _processEvent(NostrEvent event) async {
    final eventStore = ref.read(eventStorageProvider);

    if (await eventStore.hasItem(event.id!)) return;

    final sessions = ref.read(sessionNotifierProvider);
    final matchingSession = sessions.firstWhereOrNull(
      (s) => s.tradeKey.public == event.recipient,
    );
    if (matchingSession == null) {
      // Deliberately NOT marked processed: the session may simply not exist
      // yet (startup ordering, a child order being linked), and a later
      // replay must be able to retry this event.
      _holdEventForRetry(event);
      logger.w('No matching session found for recipient: ${event.recipient}');
      return;
    }
    final privateKey = matchingSession.tradeKey.private;

    try {
      // Transport branch (§5 Phase A): v1 gift wrap (kind 1059) yields an inner
      // rumor whose content is the message tuple; v2 NIP-44 direct (kind 14)
      // decrypts straight to the tuple. Both converge on jsonDecode below.
      String? content;
      String? decryptedId;
      if (event.kind == 14) {
        content = await NostrUtils.decryptNIP44DirectEvent(
          event,
          privateKey,
          expectedAuthor: _settings.mostroPublicKey,
        );
      } else {
        final decryptedEvent = await event.unWrap(privateKey);
        content = decryptedEvent.content;
        decryptedId = decryptedEvent.id;
      }

      if (content == null) {
        _holdEventForRetry(event);
        return;
      }

      final result = jsonDecode(content);

      // Ensure result is a non-empty List before accessing elements
      if (result is! List || result.isEmpty) {
        logger.w('Received empty or invalid payload, skipping');
        await _markEventProcessed(event);
        return;
      }

      // Skip dispute chat DMs — DisputeChatNotifier handles these
      // via its own adminSharedKey subscription
      if (NostrUtils.isDmPayload(result[0])) {
        logger.i('Skipping dispute chat message (handled by DisputeChatNotifier)');
        await _markEventProcessed(event);
        return;
      }

      // Skip restore-specific payloads that arrive as historical events due to temporary subscription
      if (result[0] is Map &&
          _isRestorePayload(result[0] as Map<String, dynamic>)) {
        await _markEventProcessed(event);
        return;
      }

      final msg = MostroMessage.fromJson(result[0]);

      final messageStorage = ref.read(mostroStorageProvider);

      // Use the inner rumor id if available (v1), otherwise fall back to the
      // original event id. v2 has no inner rumor, so it always falls back.
      final messageKey =
          decryptedId ??
          event.id ??
          'msg_${DateTime.now().millisecondsSinceEpoch}';
      await messageStorage.addMessage(messageKey, msg);
      logger.i(
        'Received DM, Event ID: ${decryptedId ?? event.id} with payload: $content',
      );

      await _maybeLinkChildOrder(msg, matchingSession);

      // Only now is the event durably done: a crash anywhere above leaves it
      // unmarked, so the next replay retries it (addMessage is idempotent —
      // same key, same message).
      await _markEventProcessed(event);
    } catch (e) {
      // Not marked processed: a later replay gets another chance at a
      // transient failure. A permanently undecryptable event costs one
      // decrypt attempt per replay, which the dedup above bounds to one
      // relay copy at a time.
      _holdEventForRetry(event);
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
      MostroMessage(action: Action.takeBuy, id: orderId, payload: amt),
    );
  }

  Future<void> takeSellOrder(
    String orderId,
    int? amount,
    String? lnAddress,
  ) async {
    final payload = lnAddress != null
        ? PaymentRequest(order: null, lnInvoice: lnAddress, amount: amount)
        : amount != null
        ? Amount(amount: amount)
        : null;

    await publishOrder(
      MostroMessage(action: Action.takeSell, id: orderId, payload: payload),
    );
  }

  Future<void> sendInvoice(String orderId, String invoice, int? amount) async {
    final payload = PaymentRequest(
      order: null,
      lnInvoice: invoice,
      amount: amount,
    );
    await publishOrder(
      MostroMessage(action: Action.addInvoice, id: orderId, payload: payload),
    );
  }

  Future<void> sendBondPayoutInvoice(String orderId, String invoice) async {
    final payload = PaymentRequest(order: null, lnInvoice: invoice);
    await publishOrder(
      MostroMessage(
        action: Action.addBondInvoice,
        id: orderId,
        payload: payload,
      ),
    );
  }

  Future<void> cancelOrder(String orderId) async {
    await publishOrder(MostroMessage(action: Action.cancel, id: orderId));
  }

  Future<void> sendFiatSent(String orderId) async {
    final payload = await _prepareChildOrderIfNeeded(
      orderId,
      callerLabel: 'fiatSent',
    );

    await publishOrder(
      MostroMessage(action: Action.fiatSent, id: orderId, payload: payload),
    );
  }

  Future<void> releaseOrder(String orderId) async {
    final payload = await _prepareChildOrderIfNeeded(
      orderId,
      callerLabel: 'release',
    );

    await publishOrder(
      MostroMessage(action: Action.release, id: orderId, payload: payload),
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

    return NextTrade(key: nextTradeKey.public, index: nextKeyIndex);
  }

  Future<void> disputeOrder(String orderId) async {
    await publishOrder(MostroMessage(action: Action.dispute, id: orderId));
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

    // Read PoW difficulty and protocol version from the connected Mostro
    // instance (kind 38385), waiting for it if the info event has not landed
    // yet: an outbound envelope sent on the transport the node does not speak
    // is dropped silently and never retried.
    final mostroInstance =
        await ref.read(orderRepositoryProvider).awaitMostroInstance();
    final difficulty = mostroInstance?.pow ?? 0;
    if (mostroInstance == null) {
      logger.w(
        'Mostro instance info unavailable, sending with PoW 0 — '
        'event may be rejected if node requires PoW',
      );
    }

    // Route through the transport advertised by the connected node (§5 Phase
    // B). Nodes that advertise protocol_version 1 keep the gift-wrap path
    // byte-for-byte.
    final event = await order.wrapForTransport(
      protocolVersion: mostroInstance?.protocolVersion,
      tradeKey: session.tradeKey,
      recipientPubKey: _settings.mostroPublicKey,
      masterKey: session.fullPrivacy ? null : session.masterKey,
      keyIndex: session.fullPrivacy ? null : session.keyIndex,
      difficulty: difficulty,
    );
    logger.i(
      'Sending DM (kind ${event.kind}), Event ID: ${event.id} '
      '(PoW: $difficulty) with payload: ${order.toJson()}',
    );
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
