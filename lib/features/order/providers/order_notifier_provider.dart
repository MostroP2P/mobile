import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';
import 'package:mostro_mobile/features/order/notfiers/add_order_notifier.dart';
import 'package:mostro_mobile/features/order/notfiers/order_notifier.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'order_notifier_provider.g.dart';

final orderNotifierProvider =
    StateNotifierProvider.family<OrderNotifier, OrderState, String>(
  (ref, orderId) {
    return OrderNotifier(
      orderId,
      ref,
    );
  },
);

final addOrderNotifierProvider =
    StateNotifierProvider.family<AddOrderNotifier, OrderState, String>(
  (ref, orderId) {
    return AddOrderNotifier(
      orderId,
      ref,
    );
  },
);


// This provider tracks the currently selected OrderType tab
@riverpod
class OrderTypeNotifier extends _$OrderTypeNotifier {
  @override
  OrderType build() => OrderType.sell;

  void set(OrderType value) => state = value;
}

final addOrderEventsProvider = StreamProvider.family<MostroMessage?, int>(
  (ref, requestId) {
    final storage = ref.watch(mostroStorageProvider);
    return storage.watchByRequestId(requestId);
  },
);

final orderMessagesStreamProvider = StreamProvider.family<List<MostroMessage>, String>(
  (ref, orderId) {
    final storage = ref.watch(mostroStorageProvider);
    return storage.watchAllMessages(orderId);
  },
);
