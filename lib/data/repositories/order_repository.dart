// lib/data/repositories/order_repository.dart

import 'package:mostro_mobile/data/models/order_model.dart';
import 'package:mostro_mobile/services/mostro_service.dart';

class OrderRepository {
  final MostroService _mostroService;

  OrderRepository(this._mostroService);

  Future<void> createOrder(OrderModel order) async {
    await _mostroService.publishOrder(order);
  }

  Future<void> cancelOrder(String orderId) async {
    await _mostroService.cancelOrder(orderId);
  }

  Future<void> takeSellOrder(String orderId, {int? amount}) async {
    await _mostroService.takeSellOrder(orderId, amount: amount);
  }

  Future<void> takeBuyOrder(String orderId, {int? amount}) async {
    await _mostroService.takeBuyOrder(orderId, amount: amount);
  }

  Stream<OrderModel> getPendingOrders() {
    return _mostroService.subscribeToOrders().where((order) => order.status == 'pending');
  }

  Future<void> sendFiatSent(String orderId) async {
    await _mostroService.sendFiatSent(orderId);
  }

  Future<void> releaseOrder(String orderId) async {
    await _mostroService.releaseOrder(orderId);
  }
}