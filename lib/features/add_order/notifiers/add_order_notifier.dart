import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/repositories/mostro_repository.dart';
import 'package:mostro_mobile/features/order/notfiers/abstract_order_notifier.dart';

class AddOrderNotifier extends AbstractOrderNotifier {
  final String uuid;

  AddOrderNotifier(MostroRepository orderRepository, this.uuid, Ref ref)
      : super(orderRepository, uuid, ref, Action.newOrder);

  Future<void> submitOrder(Order order) async {
    final message =
        MostroMessage<Order>(action: Action.newOrder, id: null, payload: order);
    final stream = await orderRepository.publishOrder(message);
    await subscribe(stream);
  }
}
