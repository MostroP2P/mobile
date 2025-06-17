import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/shared/providers.dart';
import 'package:mostro_mobile/features/order/notfiers/abstract_mostro_notifier.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/services/mostro_service.dart';

class AddOrderNotifier extends AbstractMostroNotifier {
  late final MostroService mostroService;
  late int requestId;

  AddOrderNotifier(super.orderId, super.ref) {
    mostroService = ref.read(mostroServiceProvider);
    requestId = _requestIdFromOrderId(orderId);
    subscribe();
  }

  int _requestIdFromOrderId(String orderId) {
    final uuid = orderId.replaceAll('-', '');
    final uuidPart1 = int.parse(uuid.substring(0, 8), radix: 16);
    final uuidPart2 = int.parse(uuid.substring(8, 16), radix: 16);
    return ((uuidPart1 ^ uuidPart2) & 0x7FFFFFFF);
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
                handleEvent(msg);
              }
            }
          },
          error: (error, stack) => handleError(error, stack),
          loading: () {},
        );
      },
    );
  }

  Future<void> _confirmOrder(MostroMessage message) async {
    state = state.updateWith(message);
    session.orderId = message.id;
    ref.read(sessionNotifierProvider.notifier).saveSession(session);
    ref.read(orderNotifierProvider(message.id!).notifier).subscribe();
    ref.read(navigationProvider.notifier).go(
          '/order_confirmed/${message.id!}',
        );
    ref.invalidateSelf();
  }

  Future<void> submitOrder(Order order) async {
    final message = MostroMessage<Order>(
      action: Action.newOrder,
      id: null,
      requestId: requestId,
      payload: order,
    );
    final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
    session = await sessionNotifier.newSession(
      requestId: requestId,
      role: order.kind == OrderType.buy ? Role.buyer : Role.seller,
    );
    mostroService.subscribe(session.tradeKey.public);
    await mostroService.submitOrder(message);
    state = state.updateWith(message);
  }
}
