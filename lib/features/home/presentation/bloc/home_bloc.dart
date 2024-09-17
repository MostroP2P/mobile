import 'package:flutter_bloc/flutter_bloc.dart';
import 'home_event.dart';
import 'home_state.dart';
import '../../../../data/repositories/order_repository.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final OrderRepository _orderRepository = OrderRepository();

  HomeBloc() : super(HomeState.initial()) {
    on<LoadOrders>(_onLoadOrders);
    on<ToggleBuySell>(_onToggleBuySell);
    on<SelectOrder>(_onSelectOrder);
  }

  void _onLoadOrders(LoadOrders event, Emitter<HomeState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final orders = await _orderRepository.getOrders();
      emit(state.copyWith(orders: orders, isLoading: false));
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  void _onToggleBuySell(ToggleBuySell event, Emitter<HomeState> emit) {
    emit(state.copyWith(isBuySelected: event.isBuySelected));
  }

  void _onSelectOrder(SelectOrder event, Emitter<HomeState> emit) {
    emit(state.copyWith(selectedOrder: event.order));
  }
}
