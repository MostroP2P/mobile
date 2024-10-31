import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mostro_mobile/services/mostro_service.dart';
import 'add_order_event.dart';
import 'add_order_state.dart';

class AddOrderBloc extends Bloc<AddOrderEvent, AddOrderState> {
  final MostroService mostroService;

  AddOrderBloc(this.mostroService) : super(const AddOrderState()) {
    on<ChangeOrderType>(_onChangeOrderType);
    on<SubmitOrder>(_onSubmitOrder);
  }

  void _onChangeOrderType(ChangeOrderType event, Emitter<AddOrderState> emit) {
    emit(state.copyWith(currentType: event.orderType));
  }

  void _onSubmitOrder(SubmitOrder event, Emitter<AddOrderState> emit) async {

    emit(state.copyWith(status: AddOrderStatus.submitting));

    await mostroService.publishOrder(event.order);

    emit(state.copyWith(status: AddOrderStatus.submitted));
  }
}
