import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mostro_mobile/presentation/order/bloc/order_details_event.dart';
import 'package:mostro_mobile/presentation/order/bloc/order_details_state.dart';

class OrderDetailsBloc extends Bloc<OrderDetailsEvent, OrderDetailsState> {
  OrderDetailsBloc() : super(const OrderDetailsState()) {
    on<LoadOrderDetails>(_onLoadOrderDetails);
    on<CancelOrder>(_onCancelOrder);
    on<ContinueOrder>(_onContinueOrder);
  }

  void _onLoadOrderDetails(
      LoadOrderDetails event, Emitter<OrderDetailsState> emit) {
    emit(state.copyWith(status: OrderDetailsStatus.loading));
    // Aquí podrías cargar información adicional si fuera necesario
    emit(state.copyWith(status: OrderDetailsStatus.loaded, order: event.order));
  }

  void _onCancelOrder(CancelOrder event, Emitter<OrderDetailsState> emit) {
    // Implementar lógica para cancelar la orden
    print('Cancelling order');
  }

  void _onContinueOrder(ContinueOrder event, Emitter<OrderDetailsState> emit) {
    // Implementar lógica para continuar con la orden
    print('Continuing with order');
  }
}
