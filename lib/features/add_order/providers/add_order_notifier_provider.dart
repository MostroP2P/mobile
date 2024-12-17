import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/features/add_order/notifiers/add_order_notifier.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';

// This provider tracks the currently selected OrderType tab
final orderTypeProvider = StateProvider<OrderType>((ref) => OrderType.sell);

final addOrderNotifierProvider =
    StateNotifierProvider.family<AddOrderNotifier, MostroMessage, String>((ref, uuid) {
  final mostroService = ref.watch(mostroRepositoryProvider);
  return AddOrderNotifier(mostroService, uuid, ref);
});
