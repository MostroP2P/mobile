import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/order_model.dart';
import 'package:mostro_mobile/presentation/home/bloc/home_event.dart';
import 'package:mostro_mobile/presentation/home/bloc/home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  StreamSubscription<OrderModel>? ordersSubscription;

  HomeBloc() : super(HomeState.initial()) {
    on<LoadOrders>(_onLoadOrders);
    on<ChangeOrderType>(_onChangeOrderType);
    on<OrderReceived>(_onOrderReceived);
    on<OrdersError>(_onOrdersError);
  }

  Future<void> _onLoadOrders(LoadOrders event, Emitter<HomeState> emit) async {
  }

  void _onOrderReceived(OrderReceived event, Emitter<HomeState> emit) {
    final updatedAllOrders = List<OrderModel>.from(state.allOrders)..add(event.order);
    final updatedFilteredOrders = _filterOrdersByType(updatedAllOrders, state.orderType);
    emit(state.copyWith(
      status: HomeStatus.loaded,
      allOrders: List.unmodifiable(updatedAllOrders),
      filteredOrders: updatedFilteredOrders,
    ));
  }

  void _onOrdersError(OrdersError event, Emitter<HomeState> emit) {
    emit(state.copyWith(
      status: HomeStatus.error,
      errorMessage: event.message,
    ));
  }

  void _onChangeOrderType(ChangeOrderType event, Emitter<HomeState> emit) {
    emit(state.copyWith(
      orderType: event.orderType,
      filteredOrders: _filterOrdersByType(state.allOrders, event.orderType),
    ));
  }

  List<OrderModel> _filterOrdersByType(
      List<OrderModel> orders, OrderType type) {
    return orders
        .where((order) =>
            type == OrderType.buy ? order.type == 'buy' : order.type == 'sell')
        .toList();
  }

  @override
  Future<void> close() {
    ordersSubscription?.cancel();
    return super.close();
  }
}
