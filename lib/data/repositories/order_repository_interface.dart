import 'package:mostro_mobile/data/models/order_model.dart';

abstract class OrderRepository {
  Future<void> createOrder(OrderModel order);

  Future<void> cancelOrder(String orderId);

  Future<void> takeSellOrder(String orderId, {int? amount});

  Future<void> takeBuyOrder(String orderId, {int? amount});

  Stream<OrderModel> getPendingOrders();

  Future<void> sendFiatSent(String orderId);

  Future<void> releaseOrder(String orderId);
}
