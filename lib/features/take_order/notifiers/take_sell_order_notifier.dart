import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/repositories/mostro_repository.dart';
import 'package:mostro_mobile/features/take_order/notifiers/take_sell_order_state.dart';

class TakeSellOrderNotifier extends StateNotifier<TakeSellOrderState> {
  final MostroRepository _orderRepository;
  final String orderId;
  final Ref ref;
  StreamSubscription<MostroMessage>? _orderSubscription;

  TakeSellOrderNotifier(this._orderRepository, this.orderId, this.ref)
      : super(TakeSellOrderState());

  void takeSellOrder(String orderId, int? amount, String? lnAddress) async {
    try {
      state = state.copyWith(status: TakeSellOrderStatus.loading);
      final stream =
          await _orderRepository.takeSellOrder(orderId, amount, lnAddress);
      _orderSubscription = stream.listen((order) {
        _handleOrderUpdate(order);
      });
    } catch (e) {
      state = state.copyWith(
        status: TakeSellOrderStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  void sendInvoice(String orderId, String invoice, int amount) async {
    await _orderRepository.sendInvoice(orderId, invoice);
  }

  void _handleOrderUpdate(MostroMessage msg) {
    switch (msg.action) {
      case Action.addInvoice:
        final order = msg.payload as Order;
        state = state.copyWith(
            status: TakeSellOrderStatus.addInvoice,
            invoiceAmount: order.amount);
        break;
      case Action.waitingSellerToPay:
        state = state.copyWith(status: TakeSellOrderStatus.done);
        break;
      default:
        state = state.copyWith(
          status: TakeSellOrderStatus.error,
          errorMessage: msg.action.value,
        );
        break;
    }
  }

  void cancelOrder() {
    state = state.copyWith(status: TakeSellOrderStatus.cancelled);
    dispose();
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    super.dispose();
  }
}
