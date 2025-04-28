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
    // Only react to PaymentRequest payloads; delegate full handling to the
    // base notifier so that the Finite-State Machine and generic side-effects
    // (navigation, notifications, etc.) remain consistent.
    if (event.payload is PaymentRequest) {
      super.handleEvent(event);
    }
  }
}
