import 'dart:async';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:dart_nostr/dart_nostr.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/mostro/protocol_version_store.dart';
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
import 'package:mostro_mobile/data/repositories/event_storage.dart';
import 'package:mostro_mobile/shared/utils/in_flight_events.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

class MostroService {
  final Ref ref;

  Settings _settings;
  StreamSubscription<NostrEvent>? _ordersSubscription;

  /// Guards against concurrent re-delivery while the durable dedup write waits
  /// for authentication. See [InFlightEvents].
  final InFlightEvents _inFlight = InFlightEvents();

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

  /// Handles one event from the orders subscription.
  ///
  /// The dedup store is written *after* the event has been authenticated, and
  /// that ordering is the security property. An event id is not evidence of
  /// anything: a relay that has seen a genuine message can copy its id onto a
  /// tampered event and deliver that first. Recording the id up front let the
  /// forgery claim the slot — it would fail decryption and be dropped, but the
  /// genuine event arriving behind it would then hit `hasItem` and be silently
  /// discarded. That is a censorship primitive available to any relay, for
  /// free, with nothing forged that has to survive a signature check.
  Future<void> _onData(NostrEvent event) async {
    final eventId = event.id;
    if (eventId == null) {
      logger.w('Ignoring event with no id');
      return;
    }

    final eventStore = ref.read(eventStorageProvider);
    if (await eventStore.hasItem(eventId)) return;

    await _inFlight.guard(eventId, () => _process(event, eventId, eventStore));
  }

  Future<void> _process(
    NostrEvent event,
    String eventId,
    EventStorage eventStore,
  ) async {
    try {
      final sessions = ref.read(sessionNotifierProvider);
      final matchingSession = sessions.firstWhereOrNull(
        (s) => s.tradeKey.public == event.recipient,
      );
      if (matchingSession == null) {
        logger.w('No matching session found for recipient: ${event.recipient}');
        return;
      }
      final privateKey = matchingSession.tradeKey.private;

      // Transport branch (§5 Phase A): v1 gift wrap (kind 1059) yields an inner
      // rumor whose content is the message tuple; v2 NIP-44 direct (kind 14)
      // decrypts straight to the tuple. Both converge on jsonDecode below.
      // Both paths pin the node as the author and verify a signature, so
      // reaching the next line means the event is the node's.
      String? content;
      String? decryptedId;
      if (event.kind == 14) {
        content = await NostrUtils.decryptNIP44DirectEvent(
          event,
          privateKey,
          expectedAuthor: _settings.mostroPublicKey,
        );
      } else {
        final decryptedEvent = await event.unWrap(
          privateKey,
          expectedAuthor: _settings.mostroPublicKey,
        );
        content = decryptedEvent.content;
        decryptedId = decryptedEvent.id;
      }

      if (content == null) return;

      // Authenticated: only now does the id earn a durable slot.
      await eventStore.putItem(eventId, {
        'id': eventId,
        'created_at': event.createdAt!.millisecondsSinceEpoch ~/ 1000,
      });

      final result = jsonDecode(content);

      // Ensure result is a non-empty List before accessing elements
      if (result is! List || result.isEmpty) {
        logger.w('Received empty or invalid payload, skipping');
        return;
      }

      // Skip dispute chat DMs — DisputeChatNotifier handles these
      // via its own adminSharedKey subscription
      if (NostrUtils.isDmPayload(result[0])) {
        logger.i('Skipping dispute chat message (handled by DisputeChatNotifier)');
        return;
      }

      // Skip restore-specific payloads that arrive as historical events due to temporary subscription
      if (result[0] is Map &&
          _isRestorePayload(result[0] as Map<String, dynamic>)) {
        return;
      }

      final msg = MostroMessage.fromJson(result[0]);

      // Freshness comes from the wire, not from when this device happened to
      // hear about it.
      //
      // On v2 the kind-14 `created_at` is covered by the node's signature —
      // the id is recomputed over it and the signature verified above — so it
      // is the node stating when it said this, and a relay cannot move it.
      // That makes it the only trustworthy clock in the protocol, and it
      // exists only here: NIP-59 deliberately randomises the wrap and seal
      // timestamps to avoid leaking timing, so the v1 path has nothing
      // equivalent and keeps falling back to receive time in MostroStorage.
      //
      // It also outranks any `timestamp` inside the decrypted payload, which
      // no signature covers independently.
      if (event.kind == 14) {
        final signedAt = event.createdAt;
        if (signedAt != null) {
          msg.timestamp = signedAt.millisecondsSinceEpoch;
        }
      }

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

    // Read PoW difficulty from the connected Mostro instance (kind 38385)
    final mostroInstance = ref.read(orderRepositoryProvider).mostroInstance;
    final difficulty = mostroInstance?.pow ?? 0;
    if (mostroInstance == null) {
      logger.w(
        'Mostro instance info unavailable, sending with PoW 0 — '
        'event may be rejected if node requires PoW',
      );
    }

    // Route through the transport the connected node speaks (§5 Phase B),
    // anchored so a relay cannot steer the send path onto v1 independently of
    // what the orders subscription is listening on.
    final event = await order.wrapForTransport(
      protocolVersion: anchoredProtocolVersionFor(ref),
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
