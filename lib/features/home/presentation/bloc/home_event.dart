import 'package:equatable/equatable.dart';

enum OrderType { buy, sell }

abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object> get props => [];
}

class LoadOrders extends HomeEvent {}

class ChangeOrderType extends HomeEvent {
  final OrderType orderType;

  const ChangeOrderType(this.orderType);

  @override
  List<Object> get props => [orderType];
}
