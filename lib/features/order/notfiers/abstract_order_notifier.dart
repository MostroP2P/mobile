import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/repositories/mostro_repository.dart';
import 'package:mostro_mobile/shared/providers/navigation_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/notification_notifier_provider.dart';

class AbstractOrderNotifier extends StateNotifier<MostroMessage> {
  final MostroRepository orderRepository;
  final Ref ref;
  final String orderId;
  StreamSubscription<MostroMessage>? _orderSubscription;

  AbstractOrderNotifier(
    this.orderRepository,
    this.orderId,
    this.ref,
  ) : super(orderRepository.getOrderById(orderId) ??
            MostroMessage(action: Action.notFound, id: orderId));

  Future<void> subscribe(Stream<MostroMessage> stream) async {
    try {
      _orderSubscription = stream.listen((order) {
        state = order;
        handleOrderUpdate();
      });
    } catch (e) {
      handleError(e);
    }
  }

  void handleError(Object err) {
    //ref.read(notificationProvider.notifier).showInformation(err.toString());
  }

  void handleOrderUpdate() {
    final navProvider = ref.read(navigationProvider.notifier);
    final notifProvider = ref.read(notificationProvider.notifier);

    switch (state.action) {
      case Action.newOrder:
        navProvider.go('/order_confirmed/${state.id!}');
        break;
      case Action.payInvoice:
        navProvider.go('/pay_invoice/${state.id!}');
        break;
      case Action.outOfRangeSatsAmount:
      case Action.outOfRangeFiatAmount:
        final order = state.getPayload<Order>();
        notifProvider.showInformation(state.action, values: {
          'min_order_amount': order?.minAmount,
          'max_order_amount': order?.maxAmount
        });
        break;
      case Action.waitingSellerToPay:
        notifProvider.showInformation(state.action, values: {'id': state.id});
        break;
      case Action.waitingBuyerInvoice:
        notifProvider.showInformation(state.action);
        break;
      case Action.buyerTookOrder:
        notifProvider.showInformation(state.action);
        break;
      case Action.fiatSentOk:
      case Action.holdInvoicePaymentSettled:
      case Action.rate:
      case Action.rateReceived:
      case Action.canceled:
      case Action.cooperativeCancelInitiatedByYou:
      case Action.disputeInitiatedByYou:
      case Action.adminSettled:
        notifProvider.showInformation(state.action);
        break;
      default:
        notifProvider.showInformation(state.action);
        break;
    }
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    super.dispose();
  }
}
