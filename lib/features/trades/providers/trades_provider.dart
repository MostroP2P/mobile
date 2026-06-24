import 'dart:math' as math;
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';


// Status filter provider - holds the currently selected status filter
final statusFilterProvider = StateProvider<Status?>((ref) => null);

// New provider that properly handles synthetic status filtering by checking OrderState
final filteredTradesWithOrderStateProvider =
    Provider<AsyncValue<List<NostrEvent>>>((ref) {
  final allOrdersAsync = ref.watch(orderEventsProvider);
  final sessions = ref.watch(sessionNotifierProvider);
  final selectedStatusFilter = ref.watch(statusFilterProvider);

  logger.d(
      'Filtering trades with OrderState: Orders state=${allOrdersAsync.toString().substring(0, math.min(100, allOrdersAsync.toString().length))}, Sessions count=${sessions.length}, Status filter=${selectedStatusFilter?.value}');

  return allOrdersAsync.when(
    data: (allOrders) {
      final orderIds = sessions.map((s) => s.orderId).toSet();
      logger
          .d('Got ${allOrders.length} orders and ${orderIds.length} sessions');

      // Make a copy to avoid modifying the original list
      final sortedOrders = List<NostrEvent>.from(allOrders);
      sortedOrders
          .sort((o1, o2) => o1.expirationDate.compareTo(o2.expirationDate));

      var filtered =
          sortedOrders.reversed.where((o) => orderIds.contains(o.orderId));

      // Watch all OrderNotifier providers for reactive updates
      final Map<String, OrderState> orderStates = {};
      for (final order in filtered) {
        if (order.orderId != null) {
          try {
            // Watch (not read) each OrderNotifier to make it reactive
            final orderState = ref.watch(orderNotifierProvider(order.orderId!));
            orderStates[order.orderId!] = orderState;
          } catch (e) {
            logger.w('Could not watch OrderState for ${order.orderId}: $e');
            // Skip this order if we can't get its state
          }
        }
      }

      // Apply status filter if one is selected - use the watched OrderStates
      if (selectedStatusFilter != null) {
        filtered = filtered.where((order) {
          if (order.orderId == null) return false;

          final orderState = orderStates[order.orderId!];
          if (orderState != null) {
            return orderState.status == selectedStatusFilter;
          } else {
            // Fallback to raw status comparison if OrderState not available
            return order.status == selectedStatusFilter;
          }
        });
      }

      final result = filtered.toList();
      logger.d('Filtered to ${result.length} trades');
      return AsyncValue.data(result);
    },
    loading: () {
      logger.d('Orders loading');
      return const AsyncValue.loading();
    },
    error: (error, stackTrace) {
      logger.e('Error filtering trades: $error');
      return AsyncValue.error(error, stackTrace);
    },
  );
});
