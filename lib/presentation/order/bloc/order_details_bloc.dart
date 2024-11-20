import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
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
    on<OrderUpdateReceived>(_onOrderUpdateReceived);
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

    late MostroMessage order;

    if (event.order.orderType == OrderType.buy.value) {
      order = await mostroService.takeBuyOrder(event.order.orderId!);
    } else {
      order = await mostroService.takeSellOrder(event.order.orderId!);
    }

    add(OrderUpdateReceived(order));
  }

  void _onOrderUpdateReceived(
      OrderUpdateReceived event, Emitter<OrderDetailsState> emit) {
    switch (event.order.action) {
      case Action.addInvoice:
      case Action.payInvoice:
      case Action.waitingSellerToPay:
        emit(state.copyWith(status: OrderDetailsStatus.done));
        break;
      case Action.notAllowedByStatus:
        emit(state.copyWith(
            status: OrderDetailsStatus.error, errorMessage: "Not allowed by status"));
        break;
      default:
        break;
    }
  }
}
