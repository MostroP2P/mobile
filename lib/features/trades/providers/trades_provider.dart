import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';


// Status filter provider - holds the currently selected status filter
final statusFilterProvider = StateProvider<Status?>((ref) => null);

/// Whether an order's status belongs under the selected filter.
///
/// The picker offers no separate "canceled by admin" entry, so orders resolved
/// by an admin cancelation stay under "canceled" instead of dropping out of
/// every filter. The distinction is surfaced in the trade detail.
bool matchesStatusFilter(Status status, Status filter) {
  if (filter == Status.canceled) {
    return status == Status.canceled || status == Status.canceledByAdmin;
  }
  return status == filter;
}

// New provider that properly handles synthetic status filtering by checking OrderState
/// The session list re-emits on every save (several per protocol step);
/// only the set of order ids matters here. A sorted joined key gives the
/// select() a value with string equality, so unchanged ids don't recompute.
final _sessionOrderIdsKeyProvider = Provider<String>((ref) {
  return ref.watch(sessionNotifierProvider.select((sessions) {
    final ids = sessions
        .map((s) => s.orderId)
        .whereType<String>()
        .toList()
      ..sort();
    return ids.join('\n');
  }));
});

final filteredTradesWithOrderStateProvider =
    Provider<AsyncValue<List<NostrEvent>>>((ref) {
  final allOrdersAsync = ref.watch(orderEventsProvider);
  final idsKey = ref.watch(_sessionOrderIdsKeyProvider);
  final selectedStatusFilter = ref.watch(statusFilterProvider);

  return allOrdersAsync.when(
    data: (allOrders) {
      final orderIds =
          idsKey.isEmpty ? const <String>{} : idsKey.split('\n').toSet();

      // Pick only the user's orders (O(book)) and sort just those (O(n log n)
      // over the sessions instead of the whole book, with the expiration tag
      // parsed once per order instead of per comparison).
      final mine = <(DateTime, NostrEvent)>[
        for (final order in allOrders)
          if (orderIds.contains(order.orderId))
            (order.expirationDate, order),
      ]..sort((a, b) => b.$1.compareTo(a.$1));

      var filtered = mine.map((entry) => entry.$2);

      // Order states are only needed when a status filter is active; watching
      // them unconditionally instantiated a notifier per session and re-ran
      // this provider on every state assignment.
      if (selectedStatusFilter != null) {
        filtered = filtered.where((order) {
          final orderId = order.orderId;
          if (orderId == null) return false;
          Status status;
          try {
            status = ref.watch(
              orderNotifierProvider(orderId).select((s) => s.status),
            );
          } catch (e) {
            logger.w('Could not watch OrderState for $orderId: $e');
            status = order.status;
          }
          return matchesStatusFilter(status, selectedStatusFilter);
        });
      }

      return AsyncValue.data(filtered.toList());
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stackTrace) {
      logger.e('Error filtering trades: $error');
      return AsyncValue.error(error, stackTrace);
    },
  );
});
