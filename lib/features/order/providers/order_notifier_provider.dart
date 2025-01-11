import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/features/order/notfiers/order_notifier.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';

final orderNotifierProvider =
    StateNotifierProvider.family<OrderNotifier, MostroMessage, String>(
  (ref, orderId) {
    final repo = ref.watch(mostroRepositoryProvider);
    return OrderNotifier(
      repo,
      orderId,
      ref,
    );
  },
);
