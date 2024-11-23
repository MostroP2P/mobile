import 'dart:convert';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/model/request/filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/data/models/content.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as actions;
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/repositories/mostro_repository.dart';
import 'package:mostro_mobile/data/repositories/secure_storage_manager.dart';
import 'package:mostro_mobile/presentation/auth/bloc/auth_state.dart';
import 'package:mostro_mobile/providers/riverpod_providers.dart';
import 'package:mostro_mobile/services/nostr_service.dart';

class MostroService {
  final NostrService _nostrService;
  final SecureStorageManager _secureStorageManager;
  final MostroRepository _mostroRepository;
  final Ref _ref;

  MostroService(this._nostrService, this._secureStorageManager,
      this._mostroRepository, this._ref);

  Stream<NostrEvent> subscribeToOrders(NostrFilter filter) {
    return _nostrService.subscribeToEvents(filter);
  }

  Future<void> publishOrder(Order order) async {
    final session = await _secureStorageManager.newSession();

    final authState = _ref.read(authNotifierProvider);
    if (authState is AuthUnauthenticated || authState is AuthUnregistered) {
      // ephermeral keys
    } else if (authState is AuthAuthenticated) {
      // user keys
    }

    final content = jsonEncode({
      'order': {
        'version': mostroVersion,
        'action': actions.Action.newOrder.value,
        'content': order.toJson(),
      },
    });

    final event = await _nostrService.createNIP59Event(
        content, Config.mostroPubKey, session.privateKey);

    await _nostrService.publishEvent(event);

    final filter = NostrFilter(p: [session.publicKey]);
    _mostroRepository.subscribeToOrders(filter, session);
  }

  Future<MostroMessage> takeSellOrder(String orderId, {int? amount}) async {
    final session = await _secureStorageManager.newSession();
    session.eventId = orderId;

    final content = jsonEncode({
      'order': {
        'version': mostroVersion,
        'id': orderId,
        'action': actions.Action.takeSell.value,
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
        'action': actions.Action.takeBuy.value,
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

    final session = await _secureStorageManager.loadSession(order.id!);

    if (session == null) {
      throw Exception('Session not found for order ID: $orderId');
    }

    final content = jsonEncode({
      'order': {
        'version': mostroVersion,
        'id': orderId,
        'action': actions.Action.cancel,
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
        'action': actions.Action.fiatSent.value,
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
        'action': actions.Action.release.value,
        'content': null,
      },
    });
    final event = await _nostrService.createNIP59Event(
        content, Config.mostroPubKey, session.privateKey);
    await _nostrService.publishEvent(event);
  }

  void notifyOrderUpdate(MostroMessage msg, BuildContext context) {
    final order = msg.content as Order;
    final orderId = order.id!;

    final message = 'Order $orderId is now ${msg.action}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            Navigator.pushNamed(
              context,
              '/order_details',
              arguments: order,
            );
          },
        ),
      ),
    );

    if (_shouldCancelSubscription(msg)) {
      _mostroRepository.cleanupExpiredOrders(DateTime.now());
    }
  }

  bool _shouldCancelSubscription(MostroMessage order) {
    return order.action == actions.Action.canceled;
  }
}
