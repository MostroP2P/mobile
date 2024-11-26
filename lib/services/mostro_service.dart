import 'dart:collection';
import 'dart:convert';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/model/request/filter.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/data/models/content.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/repositories/mostro_repository.dart';
import 'package:mostro_mobile/data/repositories/secure_storage_manager.dart';
import 'package:mostro_mobile/services/nostr_service.dart';

const int mostroVersion = 1;

class MostroService {
  final NostrService _nostrService;
  final SecureStorageManager _secureStorageManager;
  final _mostroRepository = MostroRepository();

  final _orders = HashMap<String, MostroMessage>();
  final _sessions = HashMap<String, Session>();

  MostroService(this._nostrService, this._secureStorageManager);

  Stream<NostrEvent> subscribeToOrders(NostrFilter filter) {
    return _nostrService.subscribeToEvents(filter);
  }

  Future<MostroMessage> publishOrder(Order order) async {
    final session = await _secureStorageManager.newSession();

    final content = jsonEncode({
      'order': {
        'version': mostroVersion,
        'action': Action.newOrder.value,
        'content': order.toJson(),
      },
    });

    final event = await _nostrService.createNIP59Event(
        content, Config.mostroPubKey, session.privateKey);

    await _nostrService.publishEvent(event);

    final filter = NostrFilter(p: [session.publicKey]);

    return await subscribeToOrders(filter).asyncMap((event) async {
      return await _nostrService.decryptNIP59Event(event, session.privateKey);
    }).map((event) {
      return MostroMessage.deserialized(event.content!);
    }).first;
  }

  Future<MostroMessage> takeSellOrder(String orderId, {int? amount}) async {
    final session = await _secureStorageManager.newSession();
    session.eventId = orderId;

    final content = jsonEncode({
      'order': {
        'version': mostroVersion,
        'id': orderId,
        'action': Action.takeSell.value,
        'content': amount != null ? {'amount': amount} : null,
      },
    });
    final event = await _nostrService.createNIP59Event(
        content, Config.mostroPubKey, session.privateKey);

    await _nostrService.publishEvent(event);

    final filter = NostrFilter(p: [session.publicKey]);

    return await subscribeToOrders(filter).asyncMap((event) async {
      return await _nostrService.decryptNIP59Event(event, session.privateKey);
    }).map((event) {
      return MostroMessage.deserialized(event.content!);
    }).first;
  }

  Future<MostroMessage<Content>> takeBuyOrder(String orderId,
      {int? amount}) async {
    final session = await _secureStorageManager.newSession();
    session.eventId = orderId;

    final content = jsonEncode({
      'order': {
        'version': mostroVersion,
        'id': orderId,
        'action': Action.takeBuy.value,
        'content': amount != null ? {'amount': amount} : null,
      },
    });
    final event = await _nostrService.createNIP59Event(
        content, Config.mostroPubKey, session.privateKey);
    await _nostrService.publishEvent(event);
    final filter = NostrFilter(p: [session.publicKey]);

    return await subscribeToOrders(filter).asyncMap((event) async {
      return await _nostrService.decryptNIP59Event(event, session.privateKey);
    }).map((event) {
      return MostroMessage.deserialized(event.content!);
    }).first;
  }

  Future<void> cancelOrder(String orderId) async {
    final order = _mostroRepository.getOrder(orderId);

    if (order == null) {
      throw Exception('Order not found for order ID: $orderId');
    }

    final session = await _secureStorageManager.loadSession(order!.requestId!);

    if (session == null) {
      throw Exception('Session not found for order ID: $orderId');
    }

    final content = jsonEncode({
      'order': {
        'version': mostroVersion,
        'id': orderId,
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
        'version': mostroVersion,
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
        'version': mostroVersion,
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
