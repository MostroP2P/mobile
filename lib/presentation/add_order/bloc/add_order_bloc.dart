import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/services/mostro_service.dart';
import 'add_order_event.dart';
import 'add_order_state.dart';

class AddOrderBloc extends Bloc<AddOrderEvent, AddOrderState> {
  final MostroService mostroService;

  AddOrderBloc(this.mostroService) : super(const AddOrderState()) {
    on<ChangeOrderType>(_onChangeOrderType);
    on<SubmitOrder>(_onSubmitOrder);
    on<OrderUpdateReceived>(_onOrderUpdateReceived);
  }

  void _onChangeOrderType(ChangeOrderType event, Emitter<AddOrderState> emit) {
    emit(state.copyWith(currentType: event.orderType));
  }

  Future<void> _onSubmitOrder(
      SubmitOrder event, Emitter<AddOrderState> emit) async {
    emit(state.copyWith(status: AddOrderStatus.submitting));

    

    try {
      //final order = await mostroService.publishOrder(event.order);
      //add(OrderUpdateReceived(order));
    } catch (e) {
      emit(state.copyWith(
        status: AddOrderStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  void _onOrderUpdateReceived(
      OrderUpdateReceived event, Emitter<AddOrderState> emit) {
    switch (event.order.action) {
      case Action.newOrder:
        emit(state.copyWith(status: AddOrderStatus.submitted));
        break;
      case Action.outOfRangeSatsAmount:
      case Action.outOfRangeFiatAmount:
        emit(state.copyWith(
            status: AddOrderStatus.failure, errorMessage: "Invalid amount"));
        break;
      default:
        break;
    }
  }
}
