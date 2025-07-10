import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';

class OrderActionNotifier extends StateNotifier<Action> {
  OrderActionNotifier({required this.orderId}) : super(Action.newOrder);

  final String orderId;

  void set(Action action) {
    state = action;
  }
}

final orderActionNotifierProvider =
    StateNotifierProvider.family<OrderActionNotifier, Action, String>(
  (ref, orderId) => OrderActionNotifier(orderId: orderId),
);
