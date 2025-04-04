import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/features/order/notfiers/abstract_mostro_notifier.dart';

class DisputeNotifier extends AbstractMostroNotifier<Dispute> {
  DisputeNotifier(super.orderId, super.ref) {
    sync();
    subscribe();
  }

  @override
  void handleEvent(MostroMessage event) {
    if (event.payload is Dispute) {
      state = event;
      handleOrderUpdate();
    }
  }
}
