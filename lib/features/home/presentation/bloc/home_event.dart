import 'package:equatable/equatable.dart';
import '../../../../data/models/order_model.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object> get props => [];
}

class LoadOrders extends HomeEvent {}

class ToggleBuySell extends HomeEvent {
  final bool isBuySelected;

  const ToggleBuySell(this.isBuySelected);

  @override
  List<Object> get props => [isBuySelected];
}

class SelectOrder extends HomeEvent {
  final OrderModel order;

  const SelectOrder(this.order);

  @override
  List<Object> get props => [order];
}
