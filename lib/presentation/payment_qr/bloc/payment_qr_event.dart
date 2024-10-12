import 'package:equatable/equatable.dart';

abstract class PaymentQrEvent extends Equatable {
  const PaymentQrEvent();

  @override
  List<Object> get props => [];
}

class LoadPaymentQr extends PaymentQrEvent {}

class OpenWallet extends PaymentQrEvent {}