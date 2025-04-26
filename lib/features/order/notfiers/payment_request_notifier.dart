import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/payment_request.dart';
import 'package:mostro_mobile/features/order/notfiers/abstract_mostro_notifier.dart';

class PaymentRequestNotifier extends AbstractMostroNotifier {
  PaymentRequestNotifier(super.orderId, super.ref) {
    sync();
    subscribe();
  }

  @override
  void handleEvent(MostroMessage event) {
    if (event.payload is PaymentRequest) {
      state = event;
      handleOrderUpdate();
    }
  }
}
