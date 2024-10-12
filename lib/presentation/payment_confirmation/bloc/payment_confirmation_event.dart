import 'package:equatable/equatable.dart';

abstract class PaymentConfirmationEvent extends Equatable {
  const PaymentConfirmationEvent();

  @override
  List<Object> get props => [];
}

class LoadPaymentConfirmation extends PaymentConfirmationEvent {}

class ContinueAfterConfirmation extends PaymentConfirmationEvent {}