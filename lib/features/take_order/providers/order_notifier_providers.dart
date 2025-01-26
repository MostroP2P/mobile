import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/features/take_order/notifiers/take_buy_order_notifier.dart';
import 'package:mostro_mobile/features/take_order/notifiers/take_sell_order_notifier.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';

final takeSellOrderNotifierProvider =
    StateNotifierProvider.family<TakeSellOrderNotifier, MostroMessage, String>(
        (ref, orderId) {
  final repository = ref.watch(mostroRepositoryProvider);
  return TakeSellOrderNotifier(repository, orderId, ref, Action.takeSell);
});

final takeBuyOrderNotifierProvider =
    StateNotifierProvider.family<TakeBuyOrderNotifier, MostroMessage, String>(
        (ref, orderId) {
  final repository = ref.watch(mostroRepositoryProvider);
  return TakeBuyOrderNotifier(repository, orderId, ref, Action.takeBuy);
});
