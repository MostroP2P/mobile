import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mostro_mobile/features/home/data/models/order_model.dart';
import 'package:mostro_mobile/features/home/data/repositories/order_repository.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final OrderRepository orderRepository;

  HomeBloc(this.orderRepository) : super(HomeState.initial()) {
    on<LoadOrders>(_onLoadOrders);
    on<ChangeOrderType>(_onChangeOrderType);
  }

  Future<void> _onLoadOrders(LoadOrders event, Emitter<HomeState> emit) async {
    emit(state.copyWith(status: HomeStatus.loading));
    try {
      final orders = await orderRepository.getOrdersFromNostr();
      emit(state.copyWith(
        status: HomeStatus.loaded,
        allOrders: orders,
        filteredOrders: _filterOrdersByType(orders, state.orderType),
      ));
    } catch (e) {
      emit(state.copyWith(status: HomeStatus.error));
    }
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
        .where((order) => order.type == type.toString().toLowerCase())
        .toList();
  }
}
