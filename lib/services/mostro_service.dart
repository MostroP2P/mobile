import 'dart:collection';
import 'dart:convert';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/model/request/filter.dart';
import 'package:mostro_mobile/app/config.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/repositories/secure_storage_manager.dart';
import 'package:mostro_mobile/services/nostr_service.dart';

class MostroService {
  final NostrService _nostrService;
  final SecureStorageManager _secureStorageManager;

  final _orders = HashMap<String, List<String>>();
  final _sessions = HashMap<String, Session>();

  MostroService(this._nostrService, this._secureStorageManager);

  Stream<MostroMessage> subscribe(Session session) {
    final filter = NostrFilter(p: [session.publicKey]);
    return _nostrService.subscribeToEvents(filter).asyncMap((event) async {
      try {
        final decryptedEvent =
            await _nostrService.decryptNIP59Event(event, session.privateKey);
        final msg = MostroMessage.deserialized(decryptedEvent.content!);
        return msg;
      } catch (e) {
        print('Error processing event: $e');
        return MostroMessage(action: Action.canceled, requestId: "");
      }
    });
  }

  Stream<NostrEvent> subscribeToOrders(NostrFilter filter) {
    return _nostrService.subscribeToEvents(filter);
  }

  Future<Session> takeSellOrder(
      String orderId, int? amount, String? lnAddress) async {
    final session = await _secureStorageManager.newSession();
    _sessions[orderId] = session;

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
        content, Config.mostroPubKey, session.privateKey);
    await _nostrService.publishEvent(event);
    return session;
  }

  Future<void> sendInvoice(String orderId, String invoice) async {
    final session = _sessions[orderId];

    if (session == null) {
      throw Exception('Session not found for order ID: $orderId');
    }

    final content = jsonEncode({
      'order': {
        'version': Config.mostroVersion.toInt(),
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
    });

    final event = await _nostrService.createNIP59Event(
        content, Config.mostroPubKey, session.privateKey);

    await _nostrService.publishEvent(event);
  }

  Future<Session> takeBuyOrder(String orderId, int? amount) async {
    final session = await _secureStorageManager.newSession();
    session.eventId = orderId;

    final content = jsonEncode({
      'order': {
        'version': Config.mostroVersion,
        'id': orderId,
        'action': Action.takeBuy.value,
        'content': amount != null ? {'amount': amount} : null,
      },
    });
    final event = await _nostrService.createNIP59Event(
        content, Config.mostroPubKey, session.privateKey);
    await _nostrService.publishEvent(event);
    return session;
  }

  Future<Session> publishOrder(MostroMessage order) async {
    final session = await _secureStorageManager.newSession();

    final content = jsonEncode(order.toJson());

    final event = await _nostrService.createNIP59Event(
        content, Config.mostroPubKey, session.privateKey);

    await _nostrService.publishEvent(event);
    return session;
  }

  Future<void> cancelOrder(Order order) async {
    final session = await _secureStorageManager.loadSession(order.id!);

    if (session == null) {
      throw Exception('Session not found for order ID: ${order.id}');
    }

    final content = jsonEncode({
      'order': {
        'version': Config.mostroVersion,
        'id': order.id,
        'action': Action.cancel,
        'content': null,
      },
    });
    final event = await _nostrService.createNIP59Event(
        content, Config.mostroPubKey, session.privateKey);
    await _nostrService.publishEvent(event);
  }

  Future<void> sendFiatSent(String orderId) async {
    final session = await _secureStorageManager.loadSession(orderId);

    if (session == null) {
      throw Exception('Session not found for order ID: $orderId');
    }

    final content = jsonEncode({
      'order': {
        'version': Config.mostroVersion,
        'id': orderId,
        'action': Action.fiatSent.value,
        'content': null,
      },
    });
    final event = await _nostrService.createNIP59Event(
        content, Config.mostroPubKey, session.privateKey);
    await _nostrService.publishEvent(event);
  }

  Future<void> releaseOrder(String orderId) async {
    final session = await _secureStorageManager.loadSession(orderId);

    if (session == null) {
      throw Exception('Session not found for order ID: $orderId');
    }

    final content = jsonEncode({
      'order': {
        'version': Config.mostroVersion,
        'id': orderId,
        'action': Action.release.value,
        'content': null,
      },
    });
    final event = await _nostrService.createNIP59Event(
        content, Config.mostroPubKey, session.privateKey);
    await _nostrService.publishEvent(event);
  }
}
