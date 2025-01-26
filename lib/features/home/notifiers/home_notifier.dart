import 'dart:async';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/repositories/open_orders_repository.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'home_state.dart';

class HomeNotifier extends AsyncNotifier<HomeState> {
  StreamSubscription<List<NostrEvent>>? _subscription;
  OpenOrdersRepository? _repository;

  @override
  Future<HomeState> build() async {
    state = const AsyncLoading();

    _repository = ref.watch(orderRepositoryProvider);

    _repository!.subscribeToOrders();

    _subscription = _repository!.eventsStream.listen((orders) {
      final orderType = state.value?.orderType ?? OrderType.sell;
      final filteredOrders = _filterOrders(orders, orderType);
      state = AsyncData(
        HomeState(
          orderType: orderType,
          filteredOrders: filteredOrders,
        ),
      );
    }, onError: (error) {
      state = AsyncError(error, StackTrace.current);
    });

    ref.onDispose(() {
      _subscription?.cancel();
    });

    return HomeState(
      orderType: OrderType.sell,
      filteredOrders: [],
    );
  }

  /// Refreshes the data by re-initializing the notifier.
  Future<void> refresh() async {
    _subscription?.cancel();
    await build();
  }

  List<NostrEvent> _filterOrders(List<NostrEvent> orders, OrderType type) {
    final currentState = state.value;
    if (currentState == null) return [];
    final mostroRepository = ref.watch(mostroRepositoryProvider);
    return orders
        .where((order) => type == OrderType.buy
            ? order.orderType == OrderType.buy
            : order.orderType == OrderType.sell)
        .where((order) => order.status == 'pending')
        .toList();
  }

  void changeOrderType(OrderType type) {
    final currentState = state.value;
    if (currentState == null || _repository == null) return;
    final allOrders = _repository!.currentEvents;
    final filteredOrders = _filterOrders(allOrders, type);

    state = AsyncData(
      currentState.copyWith(
        orderType: type,
        filteredOrders: filteredOrders,
      ),
    );
  }
}
