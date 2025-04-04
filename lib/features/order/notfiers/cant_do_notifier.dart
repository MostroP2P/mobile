import 'package:mostro_mobile/data/models/cant_do.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/features/order/notfiers/abstract_mostro_notifier.dart';
import 'package:mostro_mobile/shared/providers/notification_notifier_provider.dart';

class CantDoNotifier extends AbstractMostroNotifier<CantDo> {
  CantDoNotifier(super.orderId, super.ref) {
    sync();
    subscribe();
  }

  @override
  void handleEvent(MostroMessage event) {
    if (event.payload is! CantDo) return;

    final cantDo = event.getPayload<CantDo>();

    final notifProvider = ref.read(notificationProvider.notifier);
    notifProvider.showInformation(Action.cantDo, values: {
      'action': cantDo?.cantDoReason.toString() ?? '',
    });
  }
}
