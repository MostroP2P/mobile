import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/presentation/order/bloc/order_details_state.dart';
import 'package:mostro_mobile/providers/event_store_providers.dart';
import 'package:mostro_mobile/services/mostro_service.dart';

class OrderDetailsNotifier extends StateNotifier<OrderDetailsState> {
  final MostroService mostroService;

  OrderDetailsNotifier(this.mostroService)
      : super(const OrderDetailsState());

  void loadOrderDetails(NostrEvent order) {
    state = state.copyWith(status: OrderDetailsStatus.loaded, order: order);
  }

  void cancelOrder() {
    state = state.copyWith(status: OrderDetailsStatus.cancelled);
  }

  Future<void> continueOrder(NostrEvent order) async {
    state = state.copyWith(status: OrderDetailsStatus.loading);

    try {
      late MostroMessage response;

      if (order.orderType == OrderType.buy) {
        response = await mostroService.takeBuyOrder(order.orderId!);
      } else {
        response = await mostroService.takeSellOrder(order.orderId!);
      }

      handleOrderUpdate(response);
    } catch (e) {
      state = state.copyWith(
        status: OrderDetailsStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  void handleOrderUpdate(MostroMessage order) {
    switch (order.action) {
      case Action.addInvoice:
      case Action.payInvoice:
      case Action.waitingSellerToPay:
        state = state.copyWith(status: OrderDetailsStatus.done);
        break;
      case Action.notAllowedByStatus:
        state = state.copyWith(
          status: OrderDetailsStatus.error,
          errorMessage: "Not allowed by status",
        );
        break;
      default:
        break;
    }
  }
}

final orderDetailsNotifierProvider = StateNotifierProvider.family<
    OrderDetailsNotifier,
    OrderDetailsState,
    NostrEvent>((ref, initialOrder) {
  final mostroService = ref.watch(mostroServiceProvider);
  final notifier = OrderDetailsNotifier(mostroService);
  notifier.loadOrderDetails(initialOrder);
  return notifier;
});
