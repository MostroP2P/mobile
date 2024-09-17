import 'package:dart_nostr/dart_nostr.dart';
import '../models/order_model.dart';

class OrderRepository {
  final Nostr _nostr = Nostr.instance;

  Future<List<Order>> getOrders() async {
    const filter = NostrFilter(
      kinds: [38383],
      limit: 100,
    );
    final request = NostrRequest(filters: const [filter]);
    final events = await _nostr.relaysService
        .startEventsSubscriptionAsync(request: request);
    return events.map((e) => Order.fromNostrEvent(e)).toList();
  }

  Future<void> createOrder(Order order) async {
    final pubkey = await _nostr.keysService.getPublicKey();
    final event = order.toNostrEvent(pubkey);
    await _nostr.relaysService.sendEventToRelays(event);
  }

  Future<void> completeOrder(String orderId) async {
    await _sendOrderAction(orderId, 'release');
  }

  Future<void> cancelOrder(String orderId) async {
    await _sendOrderAction(orderId, 'cancel');
  }

  Future<void> _sendOrderAction(String orderId, String action) async {
    final pubkey = await _nostr.keysService.getPublicKey();
    final content = {
      'order': {
        'version': 1,
        'id': orderId,
        'pubkey': pubkey,
        'action': action,
        'content': null,
      }
    };
    final event = NostrEvent.fromPartialData(
      kind: 4,
      content: content.toString(),
      tags: [
        ['p', pubkey]
      ],
    );
    await _nostr.relaysService.sendEventToRelays(event);
  }

  Stream<Order> listenToOrderUpdates() {
    const filter = NostrFilter(kinds: [38383, 4]);
    final request = NostrRequest(filters: const [filter]);
    return _nostr.relaysService
        .startEventsSubscription(request: request)
        .stream
        .where((event) => event.kind == 38383)
        .map((event) => Order.fromNostrEvent(event));
  }
}
