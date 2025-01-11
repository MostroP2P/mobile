import 'package:mostro_mobile/features/order/notfiers/abstract_order_notifier.dart';

class TakeBuyOrderNotifier extends AbstractOrderNotifier {

  TakeBuyOrderNotifier(super.orderRepository, super.orderId, super.ref);

  void takeBuyOrder(String orderId, int? amount) async {
    final stream = await orderRepository.takeBuyOrder(orderId, amount);
    await subscribe(stream);
  }

}
