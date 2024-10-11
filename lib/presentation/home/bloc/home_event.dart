import 'package:equatable/equatable.dart';
import 'package:mostro_mobile/presentation/home/bloc/home_state.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

class LoadOrders extends HomeEvent {}

class ChangeOrderType extends HomeEvent {
  final OrderType orderType;

  const ChangeOrderType(this.orderType);

  @override
  List<Object?> get props => [orderType];
}
