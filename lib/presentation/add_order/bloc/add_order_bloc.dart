import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mostro_mobile/presentation/home/bloc/home_state.dart';
import 'add_order_event.dart';
import 'add_order_state.dart';

class AddOrderBloc extends Bloc<AddOrderEvent, AddOrderState> {
  AddOrderBloc() : super(const AddOrderState()) {
    on<ChangeOrderType>(_onChangeOrderType);
    on<SubmitOrder>(_onSubmitOrder);
  }

  void _onChangeOrderType(ChangeOrderType event, Emitter<AddOrderState> emit) {
    emit(state.copyWith(currentType: event.orderType));
  }

  void _onSubmitOrder(SubmitOrder event, Emitter<AddOrderState> emit) {
    // For now, just emit a success state
    emit(state.copyWith(status: AddOrderStatus.success));
  }
}
