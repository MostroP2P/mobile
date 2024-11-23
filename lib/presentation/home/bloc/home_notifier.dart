import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/repositories/open_orders_notifier.dart';
import 'package:mostro_mobile/presentation/home/bloc/home_state.dart';

class HomeNotifier extends StateNotifier<HomeState> {
  final OpenOrdersNotifier openOrdersNotifier;

  HomeNotifier(this.openOrdersNotifier)
      : super(HomeState(orderType: OrderType.buy, filteredOrders: []));

  void loadOrders(List<NostrEvent> orders) {
    final filteredOrders = _filterOrders(orders);
    state = state.copyWith(filteredOrders: filteredOrders);
  }

  List<NostrEvent> _filterOrders(List<NostrEvent> orders) {
    return orders.where((order) => order.orderType == state.orderType).toList();
  }

  void changeOrderType(OrderType type) {
    state = state.copyWith(orderType: type);
  }
}