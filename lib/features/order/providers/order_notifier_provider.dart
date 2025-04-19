import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/features/order/notfiers/add_order_notifier.dart';
import 'package:mostro_mobile/features/order/notfiers/dispute_notifier.dart';
import 'package:mostro_mobile/features/order/notfiers/order_notifier.dart';
import 'package:mostro_mobile/features/order/notfiers/payment_request_notifier.dart';
import 'package:mostro_mobile/services/event_bus.dart';
import 'package:mostro_mobile/features/order/notfiers/cant_do_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'order_notifier_provider.g.dart';

final orderNotifierProvider =
    StateNotifierProvider.family<OrderNotifier, MostroMessage, String>(
  (ref, orderId) {
    ref.read(cantDoNotifierProvider(orderId));
    ref.read(paymentNotifierProvider(orderId));
    ref.read(disputeNotifierProvider(orderId));
    return OrderNotifier(
      orderId,
      ref,
    );
  },
);

final addOrderNotifierProvider =
    StateNotifierProvider.family<AddOrderNotifier, MostroMessage, String>(
  (ref, orderId) {
    return AddOrderNotifier(
      orderId,
      ref,
    );
  },
);

final cantDoNotifierProvider =
    StateNotifierProvider.family<CantDoNotifier, MostroMessage, String>(
  (ref, orderId) {
    return CantDoNotifier(
      orderId,
      ref,
    );
  },
);

final paymentNotifierProvider =
    StateNotifierProvider.family<PaymentRequestNotifier, MostroMessage, String>(
  (ref, orderId) {
    return PaymentRequestNotifier(
      orderId,
      ref,
    );
  },
);

final disputeNotifierProvider =
    StateNotifierProvider.family<DisputeNotifier, MostroMessage, String>(
  (ref, orderId) {
    return DisputeNotifier(
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

final addOrderEventsProvider = StreamProvider.family<MostroMessage, int>(
  (ref, requestId) {
    final bus = ref.watch(eventBusProvider);
    return bus.stream.where(
      (msg) => msg.requestId == requestId,
    );
  },
);
