import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/features/order/notfiers/abstract_order_notifier.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';

class AddOrderNotifier extends AbstractOrderNotifier {
  AddOrderNotifier(super.orderRepository, super.orderId, super.ref);

  @override
  Future<void> subscribe(Stream<MostroMessage> stream) async {
    try {
      orderSubscription = stream.listen((order) {
        state = order;
        if (order.action == Action.newOrder) {
          confirmOrder(order);
        } else {
          handleOrderUpdate();
        }
      });
    } catch (e) {
      handleError(e);
    }
  }

  // This method would be called when the order is confirmed.
  Future<void> confirmOrder(MostroMessage confirmedOrder) async {
    // Extract the confirmed (real) order id.
    final confirmedOrderId = confirmedOrder.id;
    final newNotifier =
        ref.read(orderNotifierProvider(confirmedOrderId!).notifier);
    handleOrderUpdate();
    newNotifier.resubscribe();
    dispose();
  }

  Future<void> submitOrder(Order order) async {
    final requestId = BigInt.parse(orderId.replaceAll('-', ''), radix: 16)
        .toUnsigned(64)
        .toInt();

    final message = MostroMessage<Order>(
        action: Action.newOrder,
        id: null,
        requestId: requestId,
        payload: order);
    final stream = await orderRepository.publishOrder(message);
    await subscribe(stream);
  }
}
