import 'package:flutter_bloc/flutter_bloc.dart';
import 'payment_confirmation_event.dart';
import 'payment_confirmation_state.dart';

class PaymentConfirmationBloc extends Bloc<PaymentConfirmationEvent, PaymentConfirmationState> {
  PaymentConfirmationBloc() : super(PaymentConfirmationInitial()) {
    on<LoadPaymentConfirmation>(_onLoadPaymentConfirmation);
    on<ContinueAfterConfirmation>(_onContinueAfterConfirmation);
  }

  void _onLoadPaymentConfirmation(LoadPaymentConfirmation event, Emitter<PaymentConfirmationState> emit) {
    // TODO: Implementar lógica para cargar la confirmación de pago
  }

  void _onContinueAfterConfirmation(ContinueAfterConfirmation event, Emitter<PaymentConfirmationState> emit) {
    // TODO: Implementar lógica para continuar después de la confirmación
  }
}