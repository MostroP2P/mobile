import 'dart:convert';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:mostro_mobile/app/config.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/repositories/session_manager.dart';
import 'package:mostro_mobile/services/nostr_service.dart';

class MostroService {
  final NostrService _nostrService;
  final SessionManager _sessionManager;

  MostroService(this._nostrService, this._sessionManager);

  Stream<MostroMessage> subscribe(Session session) {
    final filter = NostrFilter(p: [session.tradeKey.public]);
    return _nostrService.subscribeToEvents(filter).asyncMap((event) async {
      final decryptedEvent = await _nostrService.decryptNIP59Event(
          event, session.tradeKey.private);
      final msg = MostroMessage.deserialized(decryptedEvent.content!);
      if (session.orderId == null && msg.requestId != null) {
        session.orderId = msg.requestId;
        await _sessionManager.saveSession(session);
      }
      return msg;
    });
  }

  Session? getSessionByOrderId(String orderId) {
    final session = _sessionManager.getSessionByOrderId(orderId);
    return session;
  }

  Future<Session> takeSellOrder(
      String orderId, int? amount, String? lnAddress) async {
    final session = await _sessionManager.newSession(orderId: orderId);
    final order = lnAddress != null
        ? {
            'payment_request': [null, lnAddress, amount]
          }
        : amount != null
            ? {'amount': amount}
            : null;

    final content = newMessage(Action.takeSell, orderId, payload: order);
    await sendMessage(orderId, Config.mostroPubKey, content);
    return session;
  }

  Future<void> sendInvoice(String orderId, String invoice) async {
    final content = newMessage(Action.addInvoice, orderId, payload: {
      'payment_request': [
        null,
        invoice,
        null,
      ]
    });
    await sendMessage(orderId, Config.mostroPubKey, content);
  }

  Future<Session> takeBuyOrder(String orderId, int? amount) async {
    final session = await _sessionManager.newSession(orderId: orderId);
    final amt = amount != null ? {'amount': amount} : null;
    final content = newMessage(Action.takeBuy, orderId, payload: amt);
    await sendMessage(orderId, Config.mostroPubKey, content);
    return session;
  }

  Future<Session> publishOrder(MostroMessage order) async {
    final session = await _sessionManager.newSession();
    String content;
    if (!session.fullPrivacy) {
      order.tradeIndex = session.keyIndex;
      final message = order.toJson();

      final serializedEvent = jsonEncode(message['order']);
      final bytes = utf8.encode(serializedEvent);
      final digest = sha256.convert(bytes);
      final hash = hex.encode(digest.bytes);
      final signature = session.tradeKey.sign(hash);
      print(signature);
      print(hash);
      print(serializedEvent);
      content = jsonEncode([message, signature]);
    } else {
      content = jsonEncode([order.toJson(), null]);
    }
    final event = await createNIP59Event(content, Config.mostroPubKey, session);
    await _nostrService.publishEvent(event);
    return session;
  }

  Future<void> cancelOrder(String orderId) async {
    final content = newMessage(Action.cancel, orderId);
    await sendMessage(orderId, Config.mostroPubKey, content);
  }

  Future<void> sendFiatSent(String orderId) async {
    final content = newMessage(Action.fiatSent, orderId);
    await sendMessage(orderId, Config.mostroPubKey, content);
  }

  Future<void> releaseOrder(String orderId) async {
    final content = newMessage(Action.release, orderId);
    await sendMessage(orderId, Config.mostroPubKey, content);
  }

  Map<String, dynamic> newMessage(Action actionType, String orderId,
      {Object? payload}) {
    return {
      'order': {
        'version': Config.mostroVersion,
        'id': orderId,
        'action': actionType.value,
        'payload': payload,
      },
    };
  }

  Future<void> sendMessage(String orderId, String receiverPubkey,
      Map<String, dynamic> content) async {
    try {
      final session = _sessionManager.getSessionByOrderId(orderId);
      String finalContent;
      if (!session!.fullPrivacy) {
        content['order']?['trade_index'] = session.keyIndex;
        final sha256Digest =
            sha256.convert(utf8.encode(jsonEncode(content))).bytes;
        final hashHex = base64.encode(sha256Digest);
        final signature = session.tradeKey.sign(hashHex);
        print(signature.codeUnits);
        finalContent = jsonEncode([content, signature]);
      } else {
        finalContent = jsonEncode([content, null]);
      }
      final event =
          await createNIP59Event(finalContent, receiverPubkey, session);
      await _nostrService.publishEvent(event);
    } catch (e) {
      // catch and throw and log and stuff
    }
  }

  Future<NostrEvent> createNIP59Event(
      String content, String recipientPubKey, Session session) async {
    final keySet = session.fullPrivacy ? session.tradeKey : session.tradeKey;

    final encryptedContent =
        await _nostrService.createRumor(content, recipientPubKey, keySet);

    final wrapperKeyPair = await _nostrService.generateKeyPair();

    String sealedContent = await _nostrService.createSeal(
        keySet, wrapperKeyPair.private, recipientPubKey, encryptedContent);

    final wrapEvent = await _nostrService.createWrap(
        wrapperKeyPair, sealedContent, recipientPubKey);

    return wrapEvent;
  }
}
