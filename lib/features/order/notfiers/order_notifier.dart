import 'dart:async';
import 'package:mostro_mobile/features/order/notfiers/abstract_order_notifier.dart';

class OrderNotifier extends AbstractOrderNotifier {
  OrderNotifier(super.orderRepository, super.orderId, super.ref, super.action) {
    _reSubscribe();
  }

  Future<void> _reSubscribe() async {
    final existingMessage = await orderRepository.getOrderById(orderId);
    if (existingMessage == null) {
      logger.e('Order $orderId not found in repository; subscription aborted.');
      return;
    }
    final stream = orderRepository.resubscribeOrder(orderId);
    await subscribe(stream);
  }
}
