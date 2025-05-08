import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as actions;
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/features/trades/models/trade_state.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:collection/collection.dart';

/// Provides a reactive TradeState for a given orderId.

final tradeStateProvider =
    Provider.family.autoDispose<TradeState, String>((ref, orderId) {
  final statusAsync = ref.watch(eventProvider(orderId));
  final messagesAsync = ref.watch(mostroMessageHistoryProvider(orderId));
  final lastOrderMessageAsync = ref.watch(mostroOrderStreamProvider(orderId));

  final status = statusAsync?.status ?? Status.pending;
  final messages = messagesAsync.value ?? [];
  final lastActionMessage =
      messages.firstWhereOrNull((m) => m.action != actions.Action.cantDo);
  final orderPayload = lastOrderMessageAsync.value?.getPayload<Order>();

  return TradeState(
    status: status,
    lastAction: lastActionMessage?.action,
    orderPayload: orderPayload,
  );
});
