import 'dart:convert';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/background/abstract_background_service.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/data/repositories.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/services/event_bus.dart';
import 'package:mostro_mobile/shared/notifiers/order_action_notifier.dart';
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';

class MostroService {
  final Ref ref;
  final SessionNotifier _sessionNotifier;
  final EventStorage _eventStorage;
  final MostroStorage _messageStorage;
  final EventBus _bus;

  Settings _settings;

  final BackgroundService backgroundService;

  MostroService(
    this._sessionNotifier,
    this._eventStorage,
    this._bus,
    this._messageStorage,
    this.ref,
    this.backgroundService,
  ) : _settings = ref.read(settingsProvider);

  Future<void> init() async {
    _eventStorage.watch().listen((data) {
      data.forEach(_handleIncomingEvent);
    });
  }

  void _handleIncomingEvent(NostrEvent event) async {

    final currentSession = getSessionByOrderId(event.subscriptionId!);
    if (currentSession == null) return;

    // Process event as you currently do:
    final decryptedEvent = await event.unWrap(currentSession.tradeKey.private);
    if (decryptedEvent.content == null) return;

    final result = jsonDecode(decryptedEvent.content!);
    if (result is! List) return;

    final msg = MostroMessage.fromJson(result[0]);
    if (msg.id != null) {
      ref.read(orderActionNotifierProvider(msg.id!).notifier).set(msg.action);
    }
    if (msg.action == Action.canceled) {
      await _messageStorage.deleteAllMessagesById(currentSession.orderId!);
      await _sessionNotifier.deleteSession(currentSession.orderId!);
      return;
    }
    await _messageStorage.addMessage(msg);
    if (currentSession.orderId == null && msg.id != null) {
      currentSession.orderId = msg.id;
      await _sessionNotifier.saveSession(currentSession);
    }
    _bus.emit(msg);
  }

  void subscribe(Session session) {
    backgroundService.subscribe({
      'kinds': [1059],
      '#p': [session.tradeKey.public],
    });
  }

  Session? getSessionByOrderId(String orderId) {
    return _sessionNotifier.getSessionByOrderId(orderId);
  }

  Future<void> submitOrder(MostroMessage order) async {
    final session = await publishOrder(order);
    subscribe(session);
  }

  Future<void> takeBuyOrder(String orderId, int? amount) async {
    final amt = amount != null ? Amount(amount: amount) : null;
    final session = await publishOrder(
      MostroMessage(
        action: Action.takeBuy,
        id: orderId,
        payload: amt,
      ),
    );
    subscribe(session);
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

    final session = await publishOrder(
      MostroMessage(
        action: Action.takeSell,
        id: orderId,
        payload: payload,
      ),
    );

    subscribe(session);
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
    await publishOrder(
      MostroMessage(
        action: Action.fiatSent,
        id: orderId,
      ),
    );
  }

  Future<void> releaseOrder(String orderId) async {
    await publishOrder(
      MostroMessage(
        action: Action.release,
        id: orderId,
      ),
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
    await publishOrder(MostroMessage(
      action: Action.rateUser,
      id: orderId,
      payload: RatingUser(userRating: rating),
    ));
  }

  Future<Session> publishOrder(MostroMessage order) async {
    final session = await _getSession(order);
    final event = await order.wrap(
      tradeKey: session.tradeKey,
      recipientPubKey: _settings.mostroPublicKey,
      masterKey: session.fullPrivacy ? null : session.masterKey,
      keyIndex: session.fullPrivacy ? null : session.keyIndex,
    );

    ref.read(nostrServiceProvider).publishEvent(event);
    return session;
  }

  Role? _getRole(MostroMessage order) {
    final payload = order.getPayload<Order>();

    return order.action == Action.newOrder
        ? payload?.kind == OrderType.buy
            ? Role.buyer
            : Role.seller
        : order.action == Action.takeBuy
            ? Role.seller
            : order.action == Action.takeSell
                ? Role.buyer
                : null;
  }

  Future<Session> _getSession(MostroMessage order) async {
    final role = _getRole(order);
    return (order.id != null)
        ? _sessionNotifier.getSessionByOrderId(order.id!) ??
            await _sessionNotifier.newSession(orderId: order.id, role: role)
        : await _sessionNotifier.newSession(role: role);
  }

  void updateSettings(Settings settings) {
    _settings = settings.copyWith();
  }
}
