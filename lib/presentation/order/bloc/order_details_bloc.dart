import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/presentation/order/bloc/order_details_event.dart';
import 'package:mostro_mobile/presentation/order/bloc/order_details_state.dart';
import 'package:mostro_mobile/services/mostro_service.dart';

class OrderDetailsBloc extends Bloc<OrderDetailsEvent, OrderDetailsState> {
  final MostroService mostroService;

  OrderDetailsBloc(this.mostroService) : super(const OrderDetailsState()) {
    on<LoadOrderDetails>(_onLoadOrderDetails);
    on<CancelOrder>(_onCancelOrder);
    on<ContinueOrder>(_onContinueOrder);
  }

  void _onLoadOrderDetails(
      LoadOrderDetails event, Emitter<OrderDetailsState> emit) {
    emit(state.copyWith(status: OrderDetailsStatus.loading));
    emit(state.copyWith(status: OrderDetailsStatus.loaded, order: event.order));
  }

  void _onCancelOrder(CancelOrder event, Emitter<OrderDetailsState> emit) {
    emit(state.copyWith(status: OrderDetailsStatus.cancelled));
  }

  void _onContinueOrder(
      ContinueOrder event, Emitter<OrderDetailsState> emit) async {
    emit(state.copyWith(status: OrderDetailsStatus.loading));

    if (event.order.orderType == OrderType.buy.value) {
      await mostroService.takeBuyOrder(event.order.orderId!);
    } else {
      await mostroService.takeSellOrder(event.order.orderId!);
    }

    emit(state.copyWith(status: OrderDetailsStatus.done));
  }
}
