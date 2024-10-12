import 'package:equatable/equatable.dart';

abstract class PaymentQrState extends Equatable {
  const PaymentQrState();
  
  @override
  List<Object> get props => [];
}

class PaymentQrInitial extends PaymentQrState {}

class PaymentQrLoading extends PaymentQrState {}

class PaymentQrLoaded extends PaymentQrState {
  final String qrData;
  final String expiresIn;

  const PaymentQrLoaded(this.qrData, this.expiresIn);

  @override
  List<Object> get props => [qrData, expiresIn];
}

class PaymentQrError extends PaymentQrState {
  final String error;

  const PaymentQrError(this.error);

  @override
  List<Object> get props => [error];
}