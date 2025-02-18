import 'dart:async';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/repositories/open_orders_repository.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/providers/session_manager_provider.dart';
import 'home_state.dart';

class HomeNotifier extends AsyncNotifier<HomeState> {
  StreamSubscription<List<NostrEvent>>? _subscription;
  OpenOrdersRepository? _repository;

  @override
  Future<HomeState> build() async {
    state = const AsyncLoading();
    _repository = ref.watch(orderRepositoryProvider);

    _subscribeToOrderUpdates();

    return HomeState(
      orderType: OrderType.sell,
      filteredOrders: [],
    );
  }

  void _subscribeToOrderUpdates() {
    _subscription?.cancel();
    _repository!.subscribeToOrders();

    _subscription = _repository!.eventsStream.listen(
      (orders) {
        _updateFilteredOrders(orders);
      },
      onError: (error) {
        state = AsyncError(error, StackTrace.current);
      },
    );

    ref.onDispose(() => _subscription?.cancel());
  }

  /// Refreshes the data by fetching new orders without rebuilding the whole notifier.
  Future<void> refresh() async {
    final orders = _repository?.currentEvents;
    if (orders != null) {
      _updateFilteredOrders(orders);
    }
  }

  void _updateFilteredOrders(List<NostrEvent> orders) {
    final orderType = state.value?.orderType ?? OrderType.sell;
    final filteredOrders = _filterOrders(orders, orderType);

    state = AsyncData(
      HomeState(
        orderType: orderType,
        filteredOrders: filteredOrders,
      ),
    );
  }

  List<NostrEvent> _filterOrders(List<NostrEvent> orders, OrderType type) {
    final sessionManager = ref.watch(sessionManagerProvider);
    final orderIds = sessionManager.sessions.map((s) => s.orderId).toSet();

    return orders
        .where((order) => !orderIds.contains(order.orderId))
        .where((order) => order.orderType == type)
        .where((order) => order.status == 'pending')
        .toList();
  }

  void changeOrderType(OrderType type) {
    final currentState = state.value;
    if (currentState == null || _repository == null) return;
    final allOrders = _repository!.currentEvents;

    state = AsyncData(
      currentState.copyWith(
        orderType: type,
      ),
    );

    _updateFilteredOrders(allOrders);

  }
}
