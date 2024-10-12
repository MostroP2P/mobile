import 'package:equatable/equatable.dart';

abstract class PaymentConfirmationState extends Equatable {
  const PaymentConfirmationState();
  
  @override
  List<Object> get props => [];
}

class PaymentConfirmationInitial extends PaymentConfirmationState {}

class PaymentConfirmationLoading extends PaymentConfirmationState {}

class PaymentConfirmationLoaded extends PaymentConfirmationState {
  final int satoshisReceived;

  const PaymentConfirmationLoaded(this.satoshisReceived);

  @override
  List<Object> get props => [satoshisReceived];
}

class PaymentConfirmationError extends PaymentConfirmationState {
  final String error;

  const PaymentConfirmationError(this.error);

  @override
  List<Object> get props => [error];
}