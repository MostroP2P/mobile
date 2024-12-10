import 'dart:async';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/repositories/open_orders_repository.dart';
import 'package:mostro_mobile/data/repositories/order_repository_interface.dart';
import 'package:mostro_mobile/services/mostro_service.dart';

class MostroRepository implements OrderRepository {
  final MostroService _mostroService;
  final OpenOrdersRepository _openOrdersRepository;
  final Map<String, MostroMessage> _messages = {};
  final Map<String, StreamSubscription<NostrEvent>> _subscriptions = {};

  final Map<String, DateTime> _orderExpirations = {};
  final StreamController<List<Order>> _streamController =
      StreamController<List<Order>>.broadcast();

  MostroRepository(this._mostroService, this._openOrdersRepository);

  Stream<List<Order>> get ordersStream => _streamController.stream;

  Order getOrderById(String orderId) {
    return _openOrdersRepository.currentEvents.where((event) {
      return event.orderId == orderId;
    }).map((event) {
      return Order.fromEvent(event);
    }).last;
  }

  Stream<MostroMessage> _subscribe(Session session) {
    return _mostroService.subscribe(session);
  }

  Future<Stream<MostroMessage>> takeSellOrder(String orderId, int? amount, String? lnAddress) async {
    final session = await _mostroService.takeSellOrder(orderId, amount, lnAddress);
    return _subscribe(session);
  }

  Future<Stream<MostroMessage>> takeBuyOrder(String orderId, int? amount) async {
    final session = await _mostroService.takeBuyOrder(orderId, amount);
    return _subscribe(session);
  }

  Future<void> sendInvoice(String orderId, String invoice) async {
    await _mostroService.sendInvoice(orderId, invoice);
  }

  Future<Stream<MostroMessage>> publishOrder(MostroMessage order) async {
    final session = await _mostroService.publishOrder(order);
    return _subscribe(session);
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _orderExpirations.clear();
    _streamController.close();
  }
}
