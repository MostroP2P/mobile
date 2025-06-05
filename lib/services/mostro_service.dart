import 'dart:convert';
import 'package:dart_nostr/nostr/model/export.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/services/lifecycle_manager.dart';
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

  void init() async {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(hours: 24));
    final sessions = _sessionNotifier.sessions;
    final messageStorage = ref.read(mostroStorageProvider);
    // Set of terminal statuses
    const terminalStatuses = {
      Status.canceled,
      Status.cooperativelyCanceled,
      Status.success,
      Status.expired,
      Status.canceledByAdmin,
      Status.settledByAdmin,
      Status.completedByAdmin,
    };
    for (final session in sessions) {
      if (session.startTime.isAfter(cutoff)) {
        if (session.orderId != null) {
          final latestOrderMsg = await messageStorage
              .getLatestMessageOfTypeById<Order>(session.orderId!);
          final status = latestOrderMsg?.payload is Order
              ? (latestOrderMsg!.payload as Order).status
              : null;
          if (status != null && terminalStatuses.contains(status)) {
            continue;
          }
        }
        subscribe(session);
      }
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
      await messageStorage.addMessage(decryptedEvent.id!, msg);
    });
  }

  Session? getSessionByOrderId(String orderId) {
    return _sessionNotifier.getSessionByOrderId(orderId);
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

    await ref.read(nostrServiceProvider).publishEvent(event);
  }

  Future<Session> _getSession(MostroMessage order) async {
    if (order.requestId != null) {
      final session = _sessionNotifier.getSessionByRequestId(order.requestId!);
      if (session == null) {
        throw Exception('No session found for requestId: ${order.requestId}');
      }
      return session;
    } else if (order.id != null) {
      final session = _sessionNotifier.getSessionByOrderId(order.id!);
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
