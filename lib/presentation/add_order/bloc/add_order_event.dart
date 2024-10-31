import 'package:equatable/equatable.dart';
import 'package:mostro_mobile/presentation/home/bloc/home_state.dart';

abstract class AddOrderEvent extends Equatable {
  const AddOrderEvent();

  @override
  List<Object> get props => [];
}

class ChangeOrderType extends AddOrderEvent {
  final OrderType orderType;

  const ChangeOrderType(this.orderType);

  @override
  List<Object> get props => [orderType];
}

class SubmitOrder extends AddOrderEvent {
  final String fiatCode;
  final double fiatAmount;
  final int satsAmount;
  final String paymentMethod;
  final OrderType orderType;

  const SubmitOrder({
    required this.fiatCode,
    required this.fiatAmount,
    required this.satsAmount,
    required this.paymentMethod,
    required this.orderType,
  });

  @override
  List<Object> get props => [fiatCode, fiatAmount, satsAmount, paymentMethod, orderType];
}