import 'package:equatable/equatable.dart';

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

enum OrderType { buy, sell }
