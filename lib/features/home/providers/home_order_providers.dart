import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';

final homeOrderTypeProvider = StateProvider((ref) => OrderType.sell);

final filteredOrdersProvider = Provider<List<NostrEvent>>((ref) {
  final allOrdersAsync = ref.watch(orderEventsProvider);
  final orderType = ref.watch(homeOrderTypeProvider);

  return allOrdersAsync.maybeWhen(
    data: (allOrders) {
      allOrders
          .sort((o1, o2) => o1.expirationDate.compareTo(o2.expirationDate));

      final filtered = allOrders.reversed
          .where((o) => o.orderType == orderType)
          .where((o) => o.status == Status.pending)
          .toList();
      return filtered;
    },
    orElse: () => [],
  );
});
