import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';
import 'package:mostro_mobile/features/order/notifiers/add_order_notifier.dart';
import 'package:mostro_mobile/features/order/notifiers/order_notifier.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';

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

class OrderTypeNotifier extends StateNotifier<OrderType> {
  OrderTypeNotifier() : super(OrderType.sell);

  void set(OrderType value) => state = value;
}

final orderTypeNotifierProvider =
    AutoDisposeStateNotifierProvider<OrderTypeNotifier, OrderType>((ref) {
  return OrderTypeNotifier();
});

final addOrderEventsProvider = StreamProvider.family<MostroMessage?, int>(
  (ref, requestId) {
    final storage = ref.watch(mostroStorageProvider);
    return storage.watchByRequestId(requestId);
  },
);

final orderMessagesStreamProvider =
    StreamProvider.family<List<MostroMessage>, String>(
  (ref, orderId) {
    final storage = ref.watch(mostroStorageProvider);
    return storage.watchAllMessages(orderId);
  },
);
