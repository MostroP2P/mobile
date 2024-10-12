import 'package:flutter_bloc/flutter_bloc.dart';
import 'payment_qr_event.dart';
import 'payment_qr_state.dart';

class PaymentQrBloc extends Bloc<PaymentQrEvent, PaymentQrState> {
  PaymentQrBloc() : super(PaymentQrInitial()) {
    on<LoadPaymentQr>(_onLoadPaymentQr);
    on<OpenWallet>(_onOpenWallet);
  }

  void _onLoadPaymentQr(LoadPaymentQr event, Emitter<PaymentQrState> emit) {
    // TODO: Implementar lógica para cargar el QR de pago
  }

  void _onOpenWallet(OpenWallet event, Emitter<PaymentQrState> emit) {
    // TODO: Implementar lógica para abrir la wallet
  }
}