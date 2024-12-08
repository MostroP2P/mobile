import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/take_order/notifiers/take_sell_order_notifier.dart';
import 'package:mostro_mobile/features/take_order/notifiers/take_sell_order_state.dart';
import 'package:mostro_mobile/providers/event_store_providers.dart';

final takeSellOrderNotifierProvider = StateNotifierProvider.family<TakeSellOrderNotifier, TakeSellOrderState, String>((ref, orderId) {
  final repository = ref.watch(mostrorRepositoryProvider);
  return TakeSellOrderNotifier(repository, orderId);
});