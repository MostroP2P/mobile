import 'dart:convert';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/providers.dart';
import 'package:logger/logger.dart';

class MostroService {
  final Ref ref;
  static final Logger _logger = Logger();
  Settings _settings;

  final Map<String, NostrKeyPairs> _subscriptions = {};
  NostrRequest? currentRequest;

  MostroService(this.ref) : _settings = ref.read(settingsProvider).copyWith();

  void init({List<NostrKeyPairs>? keys}) {
    keys?.forEach((kp) => _subscriptions[kp.public] = kp);
    _subscribe();
  }

  void subscribe(NostrKeyPairs keyPair) {
    if (_subscriptions.containsKey(keyPair.public)) return;
    _subscriptions[keyPair.public] = keyPair;
    _subscribe();
  }

  void unsubscribe(String pubKey) {
    _subscriptions.remove(pubKey);
    _subscribe();
  }

  void _subscribe() {
    final nostrService = ref.read(nostrServiceProvider);

    if (currentRequest != null) {
      nostrService.unsubscribe(
        currentRequest!.subscriptionId!,
      );
      currentRequest = null;
    }

    if (_subscriptions.isEmpty) return;

    final filter = NostrFilter(
      kinds: [1059],
      p: [..._subscriptions.keys],
    );
    currentRequest = NostrRequest(filters: [filter]);
    nostrService.subscribeToEvents(currentRequest!).listen(_onData);
  }

  Future<void> _onData(NostrEvent event) async {
    if (!_subscriptions.containsKey(event.recipient)) return;

    final eventStore = ref.read(eventStorageProvider);

    if (await eventStore.hasItem(event.id!)) return;
    await eventStore.putItem(
      event.id!,
      event,
    );

    final decryptedEvent = await event.unWrap(
      _subscriptions[event.recipient]!.private,
    );
    if (decryptedEvent.content == null) return;

    final result = jsonDecode(decryptedEvent.content!);
    if (result is! List) return;

    final msg = MostroMessage.fromJson(result[0]);
    final messageStorage = ref.read(mostroStorageProvider);
    await messageStorage.addMessage(decryptedEvent.id!, msg);
    _logger.i(
      'Received message of type ${msg.action} with order id ${msg.id}',
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
