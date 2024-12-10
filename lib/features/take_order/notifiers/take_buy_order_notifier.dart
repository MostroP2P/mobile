import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/payment_request.dart';
import 'package:mostro_mobile/data/repositories/mostro_repository.dart';
import 'package:mostro_mobile/features/take_order/notifiers/take_buy_order_state.dart';

class TakeBuyOrderNotifier extends StateNotifier<TakeBuyOrderState> {
  final MostroRepository _orderRepository;
  final String orderId;
  final Ref ref;
  StreamSubscription<MostroMessage>? _orderSubscription;

  TakeBuyOrderNotifier(this._orderRepository, this.orderId, this.ref)
      : super(TakeBuyOrderState());

  void takeBuyOrder(String orderId, int? amount) async {
    try {
      state = state.copyWith(status: TakeBuyOrderStatus.loading);
      final stream = await _orderRepository.takeBuyOrder(orderId, amount);
      _orderSubscription = stream.listen((order) {
        _handleOrderUpdate(order);
      });
    } catch (e) {
      state = state.copyWith(
        status: TakeBuyOrderStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  void _handleOrderUpdate(MostroMessage msg) {
    switch (msg.action) {
      case Action.payInvoice:
        final order = msg.payload as PaymentRequest;
        state = state.copyWith(
            status: TakeBuyOrderStatus.payInvoice, invoiceAmount: order.amount);
        break;
      case Action.waitingBuyerInvoice:
        state = state.copyWith(status: TakeBuyOrderStatus.done);
        break;

      default:
        state = state.copyWith(
          status: TakeBuyOrderStatus.error,
          errorMessage: msg.action.value,
        );
        break;
    }
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    super.dispose();
  }
}
