import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/features/order/notfiers/abstract_mostro_notifier.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/services/mostro_service.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:mostro_mobile/shared/providers/navigation_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/notification_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';

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
    requestId =
        (int.parse(uuid.substring(0, 8), radix: 16) ^ timestamp) & 0x7FFFFFFF;
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
                if (msg.action == Action.newOrder) {
                  _confirmOrder(msg);
                } else {
                  logger.i('AddOrderNotifier: received ${msg.action}');
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
    final cantDo = message.getPayload<CantDo>();
    ref.read(notificationProvider.notifier).showInformation(
      message.action,
      values: {
        'action': cantDo?.cantDoReason.toString(),
      },
    );
  }

  Future<void> _confirmOrder(MostroMessage message) async {
    state = message;
    session.orderId = message.id;
    ref.read(sessionNotifierProvider.notifier).saveSession(session);
    ref.read(orderNotifierProvider(message.id!).notifier).subscribe();
    ref.read(navigationProvider.notifier).go(
          '/order_confirmed/${message.id!}',
        );
    dispose();
  }

  Future<void> submitOrder(Order order) async {
    state = MostroMessage<Order>(
      action: Action.newOrder,
      id: null,
      requestId: requestId,
      payload: order,
    );
    final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
    session = await sessionNotifier.newSession(
      role: order.kind == OrderType.buy ? Role.buyer : Role.seller,
    );
    mostroService.subscribe(session);
    await mostroService.submitOrder(state);
  }
}
