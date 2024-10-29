import 'package:mostro_mobile/data/models/order_model.dart';
import 'package:mostro_mobile/data/repositories/order_repository_interface.dart';
import 'package:mostro_mobile/services/mostro_service.dart';

class MostroOrderRepository implements OrderRepository {
  final MostroService _mostroService;

  MostroOrderRepository(this._mostroService);

  @override
  Future<void> createOrder(OrderModel order) async {
    await _mostroService.publishOrder(order);
  }

  @override
  Future<void> cancelOrder(String orderId) async {
    await _mostroService.cancelOrder(orderId);
  }

  @override
  Future<void> takeSellOrder(String orderId, {int? amount}) async {
    await _mostroService.takeSellOrder(orderId, amount: amount);
  }

  @override
  Future<void> takeBuyOrder(String orderId, {int? amount}) async {
    await _mostroService.takeBuyOrder(orderId, amount: amount);
  }

  @override
  Stream<OrderModel> getPendingOrders() {
    return _mostroService.subscribeToOrders().where((order) => order.status == 'pending');
  }

  @override
  Future<void> sendFiatSent(String orderId) async {
    await _mostroService.sendFiatSent(orderId);
  }

  @override
  Future<void> releaseOrder(String orderId) async {
    await _mostroService.releaseOrder(orderId);
  }
}