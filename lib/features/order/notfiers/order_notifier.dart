import 'dart:async';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/features/order/notfiers/abstract_order_notifier.dart';

class OrderNotifier extends AbstractOrderNotifier {
  OrderNotifier(super.orderRepository, super.orderId, super.ref);

  Future<void> resubscribe() async {
    final stream = orderRepository.resubscribeOrder(orderId);
    Timer? debounceTimer;
    stream.listen((order) {
      // Cancel any previously scheduled update.
      debounceTimer?.cancel();
      // Schedule a new update after a debounce duration.
      debounceTimer = Timer(const Duration(milliseconds: 300), () {
        state = order;
        debounceTimer?.cancel();
        subscribe(stream);
      });
    }, onDone: () {
      debounceTimer?.cancel();
    }, onError: handleError);
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

  Future<void> sendFiatSent() async {
    await orderRepository.sendFiatSent(orderId);
  }

  Future<void> releaseOrder() async {
    await orderRepository.releaseOrder(orderId);
  }

  Future<void> disputeOrder() async {
    await orderRepository.disputeOrder(orderId);
  }

   Future<void> submitRating(int rating) async {
    await orderRepository.submitRating(orderId, rating);
   }

}
