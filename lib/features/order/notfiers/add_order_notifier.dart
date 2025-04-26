import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/cant_do.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/features/order/notfiers/abstract_mostro_notifier.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/services/mostro_service.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:mostro_mobile/shared/providers/notification_notifier_provider.dart';

class AddOrderNotifier extends AbstractMostroNotifier {
  late final MostroService mostroService;
  late int requestId;

  AddOrderNotifier(super.orderId, super.ref) {
    mostroService = ref.read(mostroServiceProvider);

    // Generate a unique requestId from the orderId but with better uniqueness
    // Take a portion of the UUID and combine with current timestamp to ensure uniqueness
    final uuid = orderId.replaceAll('-', '');
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    
    // Use only the first 8 chars of UUID combined with current timestamp for uniqueness
    // This avoids potential collisions from truncation while keeping values in int range
    requestId = (int.parse(uuid.substring(0, 8), radix: 16) ^ timestamp) & 0x7FFFFFFF;

    subscribe();
  }

  @override
  void subscribe() {
    subscription = ref.listen(
      addOrderEventsProvider(requestId),
      (_, next) {
        next.when(
          data: (msg) {
            if (msg != null) {
              if (msg.payload is Order) {
                state = msg;
                if (msg.action == Action.newOrder) {
                  confirmOrder(msg);
                }
              } else if (msg.payload is CantDo) {
                _handleCantDo(msg);
              }
            }
          },
          error: (error, stack) => handleError(error, stack),
          loading: () {},
        );
      },
    );
  }

  void _handleCantDo(MostroMessage message) {
    final notifProvider = ref.read(notificationProvider.notifier);
    final cantDo = message.getPayload<CantDo>();
    notifProvider.showInformation(
      message.action,
      values: {
        'action': cantDo?.cantDoReason.toString(),
      },
    );
  }

  Future<void> confirmOrder(MostroMessage confirmedOrder) async {
    final orderNotifier = ref.watch(
      orderNotifierProvider(confirmedOrder.id!).notifier,
    );
    handleOrderUpdate();
    orderNotifier.subscribe();
    dispose();
  }

  Future<void> submitOrder(Order order) async {
    final message = MostroMessage<Order>(
      action: Action.newOrder,
      id: null,
      requestId: requestId,
      payload: order,
    );
    await mostroService.submitOrder(message);
  }
}
