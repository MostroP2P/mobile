import 'dart:convert';
import 'package:dart_nostr/nostr/model/export.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/services/lifecycle_manager.dart';
import 'package:mostro_mobile/shared/notifiers/order_action_notifier.dart';
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';

class MostroService {
  final Ref ref;
  final SessionNotifier _sessionNotifier;

  Settings _settings;

  MostroService(
    this._sessionNotifier,
    this.ref,
  ) : _settings = ref.read(settingsProvider).copyWith() {
    init();
  }

  void init() {
    final sessions = _sessionNotifier.sessions;
    for (final session in sessions) {
      subscribe(session);
    }
  }

  void subscribe(Session session) {
    final filter = NostrFilter(
      kinds: [1059],
      p: [session.tradeKey.public],
    );

    final request = NostrRequest(filters: [filter]);

    ref.read(lifecycleManagerProvider).addSubscription(filter);

    final nostrService = ref.read(nostrServiceProvider);

    nostrService.subscribeToEvents(request).listen((event) async {
      final eventStore = ref.read(eventStorageProvider);

      if (await eventStore.hasItem(event.id!)) return;
      await eventStore.putItem(
        event.id!,
        event,
      );

      final decryptedEvent = await event.unWrap(
        session.tradeKey.private,
      );
      if (decryptedEvent.content == null) return;

      final result = jsonDecode(decryptedEvent.content!);
      if (result is! List) return;

      result[0]['timestamp'] = decryptedEvent.createdAt?.millisecondsSinceEpoch;
      final msg = MostroMessage.fromJson(result[0]);
      final messageStorage = ref.read(mostroStorageProvider);

      if (msg.id != null) {
        if (await messageStorage.hasMessageByKey(decryptedEvent.id!)) return;
        ref.read(orderActionNotifierProvider(msg.id!).notifier).set(msg.action);
      }
      if (msg.action == Action.canceled) {
        ref.read(orderNotifierProvider(session.orderId!).notifier).dispose();
        await messageStorage.deleteAllMessagesByOrderId(session.orderId!);
        await _sessionNotifier.deleteSession(session.orderId!);
        return;
      }
      await messageStorage.addMessage(decryptedEvent.id!, msg);
      if (session.orderId == null && msg.id != null) {
        session.orderId = msg.id;
        await _sessionNotifier.saveSession(session);
      }
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

    await ref.read(nostrServiceProvider).publishEvent(event);
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
