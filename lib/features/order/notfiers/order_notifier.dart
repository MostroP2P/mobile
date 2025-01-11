import 'dart:async';
import 'package:mostro_mobile/features/order/notfiers/abstract_order_notifier.dart';

class OrderNotifier extends AbstractOrderNotifier {
  OrderNotifier(super.orderRepository, super.orderId, super.ref) {
    _reSubscribe();
  }

  Future<void> _reSubscribe() async {
    final existingMessage = orderRepository.getOrderById(orderId);
    if (existingMessage == null) {
      print('Order $orderId not found in repository; subscription aborted.');
      return;
    }
    final stream = orderRepository.resubscribeOrder(orderId);
    await subscribe(stream);
  }
}
