// lib/services/mostro_service.dart

import 'dart:convert';
import 'package:dart_nostr/nostr/model/request/filter.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/data/models/order_model.dart';
import 'package:mostro_mobile/services/nostr_service.dart';

class MostroService {
  final NostrService _nostrService;

  MostroService(this._nostrService);

  Future<void> publishOrder(OrderModel order) async {
    final content = jsonEncode({
      'order': {
        'version': 1,
        'action': 'new-order',
        'content': {
          'order': order.toJson(),
        },
      },
    });
    final event = await _nostrService.createNIP59Event(content, Config.mostroPubKey);
    await _nostrService.publishEvent(event);
  }

  Future<void> cancelOrder(String orderId) async {
    final content = jsonEncode({
      'order': {
        'version': 1,
        'id': orderId,
        'action': 'cancel',
        'content': null,
      },
    });
    final event = await _nostrService.createNIP59Event(content, Config.mostroPubKey);
    await _nostrService.publishEvent(event);
  }

  Future<void> takeSellOrder(String orderId, {int? amount}) async {
    final content = jsonEncode({
      'order': {
        'version': 1,
        'id': orderId,
        'action': 'take-sell',
        'content': amount != null ? {'amount': amount} : null,
      },
    });
    final event = await _nostrService.createNIP59Event(content, Config.mostroPubKey);
    await _nostrService.publishEvent(event);
  }

  Future<void> takeBuyOrder(String orderId, {int? amount}) async {
    final content = jsonEncode({
      'order': {
        'version': 1,
        'id': orderId,
        'action': 'take-buy',
        'content': amount != null ? {'amount': amount} : null,
      },
    });
    final event = await _nostrService.createNIP59Event(content, Config.mostroPubKey);
    await _nostrService.publishEvent(event);
  }

  Stream<OrderModel> subscribeToOrders() {
    const filter = NostrFilter(
      kinds: [38383],
    );
    return _nostrService.subscribeToEvents(filter).map((event) {
      // Convertir el evento Nostr a OrderModel
      // Implementar la lógica de conversión aquí
      return OrderModel.fromEventTags(event.tags!);
    });
  }

  Future<void> sendFiatSent(String orderId) async {
    final content = jsonEncode({
      'order': {
        'version': 1,
        'id': orderId,
        'action': 'fiat-sent',
        'content': null,
      },
    });
    final event = await _nostrService.createNIP59Event(content, Config.mostroPubKey);
    await _nostrService.publishEvent(event);
  }

  Future<void> releaseOrder(String orderId) async {
    final content = jsonEncode({
      'order': {
        'version': 1,
        'id': orderId,
        'action': 'release',
        'content': null,
      },
    });
    final event = await _nostrService.createNIP59Event(content, Config.mostroPubKey);
    await _nostrService.publishEvent(event);
  }
}