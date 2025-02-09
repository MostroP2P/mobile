import 'package:mostro_mobile/features/order/notfiers/abstract_order_notifier.dart';

class TakeOrderNotifier extends AbstractOrderNotifier {
  TakeOrderNotifier(
      super.orderRepository, super.orderId, super.ref, super.action);

  Future<void> takeSellOrder(String orderId, int? amount, String? lnAddress) async {
    final stream =
        await orderRepository.takeSellOrder(orderId, amount, lnAddress);
    await subscribe(stream);
  }

  Future<void> takeBuyOrder(String orderId, int? amount) async {
    final stream = await orderRepository.takeBuyOrder(orderId, amount);
    await subscribe(stream);
  }

  Future<void> sendInvoice(String orderId, String invoice, int? amount) async {
    await orderRepository.sendInvoice(orderId, invoice);
  }

  Future<void> cancelOrder() async {
    await orderRepository.cancelOrder(orderId);
  }
}
