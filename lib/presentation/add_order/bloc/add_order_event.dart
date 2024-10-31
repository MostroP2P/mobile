import 'package:equatable/equatable.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/order.dart';

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
  final int fiatAmount;
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

  Order get order => Order(
      kind: orderType,
      fiatCode: fiatCode,
      fiatAmount: fiatAmount,
      paymentMethod: paymentMethod,
      premium: 0);

  @override
  List<Object> get props =>
      [fiatCode, fiatAmount, satsAmount, paymentMethod, orderType];
}
