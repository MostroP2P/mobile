import 'dart:convert';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/amount.dart';
import 'package:mostro_mobile/data/models/cant_do.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/payment_request.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as actions;
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';

class MostroService {
  final NostrService _nostrService;
  final SessionNotifier _sessionManager;
  final _logger = Logger();
  Settings _settings;

  MostroService(this._nostrService, this._sessionManager, this._settings);

  Stream<MostroMessage> subscribe(Session session) {
    final filter = NostrFilter(p: [session.tradeKey.public]);
    return _nostrService.subscribeToEvents(filter).asyncMap((event) async {
      _logger.i('Event received from Mostro: $event');

      final decryptedEvent = await _nostrService.decryptNIP59Event(
          event, session.tradeKey.private);

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
          await _sessionManager.deleteSession(session.keyIndex);
          return msg;
        }

        if (session.orderId == null && msg.id != null) {
          session.orderId = msg.id;
          await _sessionManager.saveSession(session);
        }
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

  Session? getSessionByOrderId(String orderId) {
    final session = _sessionManager.getSessionByOrderId(orderId);
    return session;
  }

  Future<Session> takeSellOrder(
      String orderId, int? amount, String? lnAddress) async {
    final payload = lnAddress != null
        ? PaymentRequest(order: null, lnInvoice: lnAddress, amount: amount)
        : amount != null
            ? Amount(amount: amount)
            : null;
    final order =
        MostroMessage(action: Action.takeSell, id: orderId, payload: payload);

    final session = await publishOrder(order);
    return session;
  }

  Future<void> sendInvoice(String orderId, String invoice, int? amount) async {
    final payload =
        PaymentRequest(order: null, lnInvoice: invoice, amount: amount);
    final order =
        MostroMessage(action: Action.addInvoice, id: orderId, payload: payload);
    await publishOrder(order);
  }

  Future<Session> takeBuyOrder(String orderId, int? amount) async {
    final amt = amount != null ? Amount(amount: amount) : null;
    final order =
        MostroMessage(action: Action.takeBuy, id: orderId, payload: amt);
    final session = await publishOrder(order);
    return session;
  }

  Future<Session> publishOrder(MostroMessage order) async {
    final session = (order.id != null)
        ? _sessionManager.getSessionByOrderId(order.id!) ??
            await _sessionManager.newSession(orderId: order.id)
        : await _sessionManager.newSession();

    String content;
    if (!session.fullPrivacy) {
      order.tradeIndex = session.keyIndex;
      content = order.serialize(keyPair: session.tradeKey);
    } else {
      content = order.serialize();
    }
    _logger.i('Publishing order: $content');
    final event =
        await createNIP59Event(content, _settings.mostroPublicKey, session);
    await _nostrService.publishEvent(event);
    return session;
  }

  Future<void> cancelOrder(String orderId) async {
    final order = MostroMessage(action: Action.cancel, id: orderId);
    await publishOrder(order);
  }

  Future<void> sendFiatSent(String orderId) async {
    final order = MostroMessage(action: Action.fiatSent, id: orderId);
    await publishOrder(order);
  }

  Future<void> releaseOrder(String orderId) async {
    final order = MostroMessage(action: Action.release, id: orderId);
    await publishOrder(order);
  }

  Future<NostrEvent> createNIP59Event(
      String content, String recipientPubKey, Session session) async {
    final keySet = session.fullPrivacy ? session.tradeKey : session.masterKey;

    final encryptedContent = await _nostrService.createRumor(
        session.tradeKey, keySet.private, recipientPubKey, content);

    final wrapperKeyPair = await _nostrService.generateKeyPair();

    String sealedContent = await _nostrService.createSeal(
        keySet, wrapperKeyPair.private, recipientPubKey, encryptedContent);

    final wrapEvent = await _nostrService.createWrap(
        wrapperKeyPair, sealedContent, recipientPubKey);

    return wrapEvent;
  }

  void updateSettings(Settings settings) {
    _settings = settings.copyWith();
  }
}
