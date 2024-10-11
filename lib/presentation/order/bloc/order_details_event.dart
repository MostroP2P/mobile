import 'package:equatable/equatable.dart';
import 'package:mostro_mobile/data/models/order_model.dart';

abstract class OrderDetailsEvent extends Equatable {
  const OrderDetailsEvent();

  @override
  List<Object> get props => [];
}

class LoadOrderDetails extends OrderDetailsEvent {
  final OrderModel order;

  const LoadOrderDetails(this.order);

  @override
  List<Object> get props => [order];
}

class CancelOrder extends OrderDetailsEvent {}

class ContinueOrder extends OrderDetailsEvent {}
