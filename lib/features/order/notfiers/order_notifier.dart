import 'dart:async';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/features/order/notfiers/abstract_order_notifier.dart';

class OrderNotifier extends AbstractOrderNotifier {
  OrderNotifier(super.orderRepository, super.orderId, super.ref);

  Future<void> reSubscribe() async {
    final existingMessage = await orderRepository.getOrderById(orderId);
    if (existingMessage == null) {
      logger.e('Order $orderId not found in repository; subscription aborted.');
      return;
    }
    final stream = orderRepository.resubscribeOrder(orderId);
    await subscribe(stream);
  }

  Future<void> takeSellOrder(
      String orderId, int? amount, String? lnAddress) async {
    final stream =
        await orderRepository.takeSellOrder(orderId, amount, lnAddress);
    await subscribe(stream);
  }

  Future<void> takeBuyOrder(String orderId, int? amount) async {
    final stream = await orderRepository.takeBuyOrder(orderId, amount);
    await subscribe(stream);
  }

  Future<void> sendInvoice(String orderId, String invoice, int? amount) async {
    await orderRepository.sendInvoice(orderId, invoice, amount);
  }

  Future<void> cancelOrder() async {
    await orderRepository.cancelOrder(orderId);
  }

  Future<void> submitOrder(Order order) async {
    final message =
        MostroMessage<Order>(action: Action.newOrder, id: null, payload: order);
    final stream = await orderRepository.publishOrder(message);
    await subscribe(stream);
  }
}
