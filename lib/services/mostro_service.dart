import 'dart:convert';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/amount.dart';
import 'package:mostro_mobile/data/models/cant_do.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/enums/role.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/payment_request.dart';
import 'package:mostro_mobile/data/models/rating_user.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/repositories/mostro_storage.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as actions;
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';

class MostroService {
  final NostrService _nostrService;
  final SessionNotifier _sessionNotifier;
  final MostroStorage _messageStorage;
  final _logger = Logger();
  Settings _settings;

  MostroService(this._nostrService, this._sessionNotifier, this._settings,
      this._messageStorage);

  Future<MostroMessage?> getOrderById(String orderId) async {
    return await _messageStorage.getOrderById(orderId);
  }

  Future<void> sync(Session session) async {
    final filter = NostrFilter(
      kinds: [1059],
      p: [session.tradeKey.public],
    );
    final events = await _nostrService.fecthEvents(filter);
    List<MostroMessage> orders = [];
    final eventsCopy = List<NostrEvent>.from(events);

    for (final event in eventsCopy) {
      final decryptedEvent = await event.unWrap(
        session.tradeKey.private,
      );

      if (decryptedEvent.content == null) {
        _logger.i('Event ${decryptedEvent.id} content is null');
        continue;
      }

      final result = jsonDecode(decryptedEvent.content!);

      if (result is! List) {
        _logger.e('Event content ${decryptedEvent.content} should be a List');
        continue;
      }

      final msgMap = result[0];

      if (msgMap.containsKey('order')) {
        final msg = MostroMessage.fromJson(msgMap['order']);
        orders.add(msg);
      } else if (msgMap.containsKey('cant-do')) {
        //final msg = MostroMessage.fromJson(msgMap['cant-do']);
        //orders.add(msg);
      } else {
        _logger.e('Result not found ${decryptedEvent.content}');
      }
    }

    _messageStorage.addOrders(orders);
  }

  Stream<MostroMessage> subscribe(Session session) {
    final filter = NostrFilter(
      kinds: [1059],
      p: [session.tradeKey.public],
    );
    return _nostrService.subscribeToEvents(filter).asyncMap((event) async {
      _logger.i('Event received from Mostro: $event');

      final decryptedEvent = await event.unWrap(
        session.tradeKey.private,
      );

      // Check event content is not null
      if (decryptedEvent.content == null) {
        _logger.i('Event ${decryptedEvent.id} content is null');
        throw FormatException('Event ${decryptedEvent.id} content is null');
      }

      // Deserialize the message content:
      final result = jsonDecode(decryptedEvent.content!);

      _logger.i('Decrypted Mostro event content: $result');

      // The result should be an array of two elements, the first being
      // A MostroMessage or CantDo
      if (result is! List) {
        throw FormatException(
            'Event content ${decryptedEvent.content} should be a List');
      }

      final msgMap = result[0];

      if (msgMap.containsKey('order')) {
        final msg = MostroMessage.fromJson(msgMap['order']);

        if (msg.action == actions.Action.canceled) {
          await _sessionNotifier.deleteSession(session.orderId!);
          return msg;
        }

        if (session.orderId == null && msg.id != null) {
          session.orderId = msg.id;
          await _sessionNotifier.saveSession(session);
        }
        await _saveMessage(msg);
        return msg;
      }

      if (msgMap.containsKey('cant-do')) {
        final msg = MostroMessage.fromJson(msgMap['cant-do']);
        final cantdo = msg.getPayload<CantDo>();
        _logger.e('Can\'t Do: ${cantdo?.cantDoReason}');
        return msg;
      }
      throw FormatException('Result not found ${decryptedEvent.content}');
    });
  }

  Future<void> _saveMessage(MostroMessage message) async {
    await _messageStorage.addOrder(message);
  }

  Session? getSessionByOrderId(String orderId) {
    return _sessionNotifier.getSessionByOrderId(orderId);
  }

  Future<Session> takeBuyOrder(String orderId, int? amount) async {
    final amt = amount != null ? Amount(amount: amount) : null;
    return await publishOrder(
      MostroMessage(
        action: Action.takeBuy,
        id: orderId,
        payload: amt,
      ),
    );
  }

  Future<Session> takeSellOrder(
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

    return await publishOrder(
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
