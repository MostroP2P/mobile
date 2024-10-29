import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mostro_mobile/data/models/order_model.dart';
import 'package:mostro_mobile/data/repositories/mostro_order_repository.dart';
import 'package:mostro_mobile/presentation/home/bloc/home_event.dart';
import 'package:mostro_mobile/presentation/home/bloc/home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {

  final OrderRepository orderRepository;

  HomeBloc(this.orderRepository) : super(HomeState.initial()) {
    on<LoadOrders>(_onLoadOrders);
    on<ChangeOrderType>(_onChangeOrderType);
  }

  void _onLoadOrders(LoadOrders event, Emitter<HomeState> emit) {
    emit(state.copyWith(status: HomeStatus.loading));

    // Datos hardcodeados
    final hardcodedOrders = List<OrderModel>.empty();

    emit(state.copyWith(
      status: HomeStatus.loaded,
      allOrders: hardcodedOrders,
      filteredOrders: _filterOrdersByType(hardcodedOrders, state.orderType),
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
}
