import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/providers/session_manager_provider.dart';

final filteredTradesProvider = Provider<List<NostrEvent>>((ref) {
  final allOrdersAsync = ref.watch(orderEventsProvider);
  final sessions = ref.watch(sessionNotifierProvider);

  return allOrdersAsync.maybeWhen(
    data: (allOrders) {
      final orderIds = sessions.map((s) => s.orderId).toSet();

      allOrders
          .sort((o1, o2) => o1.expirationDate.compareTo(o2.expirationDate));

      final filtered = allOrders.reversed
          .where((o) => orderIds.contains(o.orderId))
          .where((o) => o.status != Status.canceled)
          .where((o) => o.status != Status.canceledByAdmin)
          .toList();
      return filtered;
    },
    orElse: () => [],
  );
});
