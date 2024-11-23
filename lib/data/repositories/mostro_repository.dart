import 'dart:async';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/model/request/filter.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/repositories/order_repository_interface.dart';
import 'package:mostro_mobile/services/nostr_service.dart';

class MostroRepository implements OrderRepository {
  final NostrService _nostrService;
  final Map<String, Order> _orders = {};
  final Map<String, StreamSubscription<NostrEvent>> _subscriptions = {};
  final Map<String, DateTime> _orderExpirations = {};
  final StreamController<List<Order>> _streamController =
      StreamController<List<Order>>.broadcast();

  MostroRepository(this._nostrService);

  Stream<List<Order>> get ordersStream => _streamController.stream;

  void subscribeToOrders(NostrFilter filter, Session session) {
    final subscription = _nostrService.subscribeToEvents(filter).listen(
      (event) async {
        try {
          final decryptedEvent = await _nostrService.decryptNIP59Event(event, session.privateKey);
          final msg = MostroMessage.deserialized(decryptedEvent.content!);

          final order = msg.content as Order;
          final orderId = order.id;
          _orders[orderId!] = order;

          // Track expiration
          if (order.expiresAt != null) {
            _orderExpirations[orderId] =
                DateTime.fromMillisecondsSinceEpoch(order.expiresAt!);
          }

          // Notify listeners
          _streamController.add(_orders.values.toList());
        } catch (e) {
          print('Error processing event: $e');
        }
      },
    );

    _subscriptions[session.publicKey] = subscription;
  }

  Order? getOrder(String orderId) => _orders[orderId];

  void cleanupExpiredOrders(DateTime now) {
    _orders.removeWhere((_, order) {
      final expiration = DateTime.fromMillisecondsSinceEpoch(order.createdAt!)
          .add(Duration(hours: 48));
      return expiration.isBefore(now);
    });
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _orders.clear();
    _orderExpirations.clear();
    _streamController.close();
  }
}
