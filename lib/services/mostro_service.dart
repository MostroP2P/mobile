import 'dart:convert';
import 'package:dart_nostr/nostr/model/request/filter.dart';
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
    final filter = NostrFilter(p: [session.masterKey.public]);
    return _nostrService.subscribeToEvents(filter).asyncMap((event) async {
      final decryptedEvent = await _nostrService.decryptNIP59Event(
          event, session.masterKey.private);
      final msg = MostroMessage.deserialized(decryptedEvent.content!);
      if (session.orderId == null && msg.requestId != null) {
        session.orderId = msg.requestId;
        await _sessionManager.saveSession(session);
      }
      return msg;
    });
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

    final content = jsonEncode({
      'order': {
        'version': Config.mostroVersion,
        'id': orderId,
        'action': Action.takeSell.value,
        'content': order,
      },
    });

    final event = await _nostrService.createNIP59Event(
        content, Config.mostroPubKey, session.masterKey.private);
    await _nostrService.publishEvent(event);
    return session;
  }

  Future<void> sendInvoice(String orderId, String invoice) async {
    final content = {
      'order': {
        'version': Config.mostroVersion,
        'id': orderId,
        'action': Action.addInvoice.value,
        'content': {
          'payment_request': [
            null,
            invoice,
            null,
          ]
        },
      },
    };

    try {
      final session = _sessionManager.getSessionByOrderId(orderId);
      final event = await _nostrService.createNIP59Event(
          jsonEncode(content), Config.mostroPubKey, session.masterKey.private);

      await _nostrService.publishEvent(event);
    } catch (e) {
      // check and log error kinds
    }
  }

  Future<Session> takeBuyOrder(String orderId, int? amount) async {
    final session = await _sessionManager.newSession(orderId: orderId);

    final content = jsonEncode({
      'order': {
        'version': Config.mostroVersion,
        'id': orderId,
        'action': Action.takeBuy.value,
        'content': amount != null ? {'amount': amount} : null,
      },
    });
    final event = await _nostrService.createNIP59Event(
        content, Config.mostroPubKey, session.masterKey.private);
    await _nostrService.publishEvent(event);
    return session;
  }

  Future<Session> publishOrder(MostroMessage order) async {
    final session = await _sessionManager.newSession();

    final content = jsonEncode(order.toJson());

    final event = await _nostrService.createNIP59Event(
        content, Config.mostroPubKey, session.masterKey.private);

    await _nostrService.publishEvent(event);
    return session;
  }

  Future<void> cancelOrder(String orderId) async {
    final content = jsonEncode({
      'order': {
        'version': Config.mostroVersion,
        'id': orderId,
        'action': Action.cancel.value,
        'content': null,
      },
    });

    try {
      final session = _sessionManager.getSessionByOrderId(orderId);
      final event = await _nostrService.createNIP59Event(
          content, Config.mostroPubKey, session.masterKey.private);
      await _nostrService.publishEvent(event);
    } catch (e) {
      // catch and throw!
    }
  }

  Future<void> sendFiatSent(String orderId) async {
    final content = jsonEncode({
      'order': {
        'version': Config.mostroVersion,
        'id': orderId,
        'action': Action.fiatSent.value,
        'content': null,
      },
    });

    try {
      final session = _sessionManager.getSessionByOrderId(orderId);
      final event = await _nostrService.createNIP59Event(
          content, Config.mostroPubKey, session.masterKey.private);
      await _nostrService.publishEvent(event);
    } catch (e) {
      // catch and throw and log and stuff
    }
  }

  Future<void> releaseOrder(String orderId) async {
    final content = jsonEncode({
      'order': {
        'version': Config.mostroVersion,
        'id': orderId,
        'action': Action.release.value,
        'content': null,
      },
    });
    try {
      final session = _sessionManager.getSessionByOrderId(orderId);
      final event = await _nostrService.createNIP59Event(
          content, Config.mostroPubKey, session.masterKey.private);
      await _nostrService.publishEvent(event);
    } catch (e) {
      // catch and throw and log and stuff
    }
  }
}
