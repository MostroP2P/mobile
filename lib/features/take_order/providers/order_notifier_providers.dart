import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/features/take_order/notifiers/take_order_notifier.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';

final takeSellOrderNotifierProvider =
    StateNotifierProvider.family<TakeOrderNotifier, MostroMessage, String>(
        (ref, orderId) {
  final repository = ref.watch(mostroRepositoryProvider);
  return TakeOrderNotifier(repository, orderId, ref, Action.takeSell);
});

final takeBuyOrderNotifierProvider =
    StateNotifierProvider.family<TakeOrderNotifier, MostroMessage, String>(
        (ref, orderId) {
  final repository = ref.watch(mostroRepositoryProvider);
  return TakeOrderNotifier(repository, orderId, ref, Action.takeBuy);
});
