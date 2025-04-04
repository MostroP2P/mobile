import 'dart:convert';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/amount.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as actions;
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/enums/role.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/payment_request.dart';
import 'package:mostro_mobile/data/models/rating_user.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/repositories/event_storage.dart';
import 'package:mostro_mobile/data/repositories/mostro_storage.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/services/event_bus.dart';
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/shared/notifiers/order_action_notifier.dart';
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';

class MostroService {
  final Ref ref;
  final NostrService _nostrService;
  final SessionNotifier _sessionNotifier;
  final EventStorage _eventStorage;
  final MostroStorage _messageStorage;

  final EventBus _bus;

  Settings _settings;

  MostroService(
    this._sessionNotifier,
    this._eventStorage,
    this._bus,
    this._messageStorage,
    this.ref,
  )   : _nostrService = ref.read(nostrServiceProvider),
        _settings = ref.read(settingsProvider);

  void subscribe(Session session) {
    final filter = NostrFilter(
      kinds: [1059],
      p: [session.tradeKey.public],
    );

    _nostrService.subscribeToEvents(filter).listen((event) async {
      // The item has already beeen processed
      if (await _eventStorage.hasItem(event.id!)) return;
      // Store the event
      await _eventStorage.putItem(
        event.id!,
        event,
      );

      final decryptedEvent = await event.unWrap(
        session.tradeKey.private,
      );
      if (decryptedEvent.content == null) return;

      final result = jsonDecode(decryptedEvent.content!);
      if (result is! List) return;

      final msgMap = result[0];

      final msg = MostroMessage.fromJson(
        msgMap['order'] ?? msgMap['cant-do'],
      );

      ref.read(orderActionNotifierProvider(msg.id!).notifier).set(msg.action,);

      if (msg.action == actions.Action.canceled) {
        await _messageStorage.deleteAllMessagesById(session.orderId!);
        await _sessionNotifier.deleteSession(session.orderId!);
        return;
      }

      await _messageStorage.addMessage(msg);

      if (session.orderId == null && msg.id != null) {
        session.orderId = msg.id;
        await _sessionNotifier.saveSession(session);
      }

      _bus.emit(msg);
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
    await _nostrService.publishEvent(event);
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
