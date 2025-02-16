import 'dart:async';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/repositories/open_orders_repository.dart';
import 'package:mostro_mobile/features/trades/notifiers/trades_state.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/providers/session_manager_provider.dart';

class TradesNotifier extends AsyncNotifier<TradesState> {
  OpenOrdersRepository? _repository;
  StreamSubscription<List<NostrEvent>>? _subscription;


  @override
  FutureOr<TradesState> build() async {
    state = const AsyncLoading();

    _repository = ref.watch(orderRepositoryProvider);
    _repository!.subscribeToOrders();

    _subscription = _repository!.eventsStream.listen((orders) {
      final filteredOrders = _filterOrders(orders);
      state = AsyncData(
        TradesState(
          filteredOrders,
        ),
      );
    }, onError: (error) {
      state = AsyncError(error, StackTrace.current);
    });

    ref.onDispose(() {
      _subscription?.cancel();
    });

    return TradesState([]);
  }

  /// Refreshes the data by re-initializing the notifier.
  Future<void> refresh() async {
    _subscription?.cancel();
    await build();
  }

  List<NostrEvent> _filterOrders(List<NostrEvent> orders) {
    final currentState = state.value;
    if (currentState == null) return [];

    final sessionManager = ref.watch(sessionManagerProvider);
    final orderIds = sessionManager.sessions.map((s) => s.orderId);

    return orders
        .where((order) => orderIds.contains(order.orderId))
        .toList();
  }

}
