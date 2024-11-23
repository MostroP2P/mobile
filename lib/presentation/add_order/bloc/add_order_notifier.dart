import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/presentation/add_order/bloc/add_order_state.dart';
import 'package:mostro_mobile/services/mostro_service.dart';

class AddOrderNotifier extends StateNotifier<AddOrderState> {
  final MostroService mostroService;

  AddOrderNotifier(this.mostroService) : super(const AddOrderState());

  void changeOrderType(OrderType orderType) {
    state = state.copyWith(currentType: orderType);
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
      await mostroService.publishOrder(Order(
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
}
