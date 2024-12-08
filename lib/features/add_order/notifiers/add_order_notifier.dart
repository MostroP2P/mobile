import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/features/add_order/notifiers/add_order_state.dart';
import 'package:mostro_mobile/services/mostro_service.dart';

class AddOrderNotifier extends StateNotifier<AddOrderState> {
  final MostroService _mostroService;

  AddOrderNotifier(this._mostroService) : super(const AddOrderState());

  void changeOrderType(OrderType orderType) {
    state = state.copyWith(currentType: orderType);
  }

  void reset() {
    state = state.copyWith(status: AddOrderStatus.initial);
  }

  Future<void> submitOrder(
    String fiatCode,
    int fiatAmount,
    int satsAmount,
    String paymentMethod,
    OrderType orderType,
  ) async {
    state = state.copyWith(status: AddOrderStatus.submitting);

    try {
      await _mostroService.publishOrder(Order(
        fiatCode: fiatCode,
        fiatAmount: fiatAmount,
        amount: satsAmount,
        paymentMethod: paymentMethod,
        kind: orderType,
        premium: 0,
      ));
    } catch (e) {
      state = state.copyWith(
        status: AddOrderStatus.failure,
        errorMessage: e.toString(),
      );
    }
  }

  void _handleOrderUpdate(MostroMessage order) {
    switch (order.action) {
      case Action.newOrder:
        state = state.copyWith(status: AddOrderStatus.submitted);
        break;
      case Action.outOfRangeSatsAmount:
      case Action.outOfRangeFiatAmount:
        state = state.copyWith(
          status: AddOrderStatus.failure,
          errorMessage: "Invalid amount",
        );
        break;
      default:
        // Handle other actions if necessary
        break;
    }
  }
}
