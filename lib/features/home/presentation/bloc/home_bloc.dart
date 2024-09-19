import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mostro_mobile/data/repositories/order_repository.dart';

import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final OrderRepository _orderRepository;

  HomeBloc({required OrderRepository orderRepository})
      : _orderRepository = orderRepository,
        super(const HomeState()) {
    on<LoadOrders>(_onLoadOrders);
    on<ChangeOrderType>(_onChangeOrderType);
  }

  Future<void> _onLoadOrders(LoadOrders event, Emitter<HomeState> emit) async {
    emit(state.copyWith(status: HomeStatus.loading));
    try {
      final orders = await _orderRepository.getOrders();
      emit(state.copyWith(status: HomeStatus.loaded, orders: orders));
    } catch (_) {
      emit(state.copyWith(status: HomeStatus.error));
    }
  }

  void _onChangeOrderType(ChangeOrderType event, Emitter<HomeState> emit) {
    emit(state.copyWith(orderType: event.orderType));
  }
}
