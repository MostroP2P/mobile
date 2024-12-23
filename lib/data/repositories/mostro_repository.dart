import 'dart:async';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/repositories/order_repository_interface.dart';
import 'package:mostro_mobile/services/mostro_service.dart';

class MostroRepository implements OrderRepository {
  final MostroService _mostroService;
  final Map<String, MostroMessage> _messages = {};

  final Map<String, StreamSubscription<MostroMessage>> _subscriptions = {};
  
  final StreamController<List<Order>> _streamController =
      StreamController<List<Order>>.broadcast();

  MostroRepository(this._mostroService);

  Stream<List<Order>> get ordersStream => _streamController.stream;

  MostroMessage? getOrderById(String orderId) => _messages[orderId];

  Stream<MostroMessage> _subscribe(Session session) {
    return _mostroService.subscribe(session)..listen((m) {
      _messages[m.requestId!] = m;
    });
  }

  Future<Stream<MostroMessage>> takeSellOrder(
      String orderId, int? amount, String? lnAddress) async {
    final session =
        await _mostroService.takeSellOrder(orderId, amount, lnAddress);
    return _subscribe(session);
  }

  Future<Stream<MostroMessage>> takeBuyOrder(
      String orderId, int? amount) async {
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

  void cancelOrder(String orderId) async {
    await _mostroService.cancelOrder(orderId);
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _streamController.close();
  }
}
