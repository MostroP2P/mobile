import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/repositories/mostro_repository.dart';
import 'package:mostro_mobile/shared/providers/navigation_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/notification_notifier_provider.dart';

class OrderNotifier extends StateNotifier<MostroMessage> {
  final MostroRepository orderRepository;
  final Ref ref;
  final String orderId;
  StreamSubscription<MostroMessage>? _orderSubscription;

  OrderNotifier({
    required this.orderRepository,
    required this.orderId,
    required this.ref,
  }) : super(orderRepository.getOrderById(orderId) ??
            MostroMessage(action: Action.notFound, requestId: orderId)) {
    subscribe();
  }

  Future<void> subscribe() async {
    final existingMessage = orderRepository.getOrderById(orderId);
    if (existingMessage == null) {
      print('Order $orderId not found in repository; subscription aborted.');
      return;
    }
    final stream = orderRepository.resubscribeOrder(orderId);
    _orderSubscription = stream.listen((msg) {
      state = msg;
      _handleOrderUpdate();
    }, onError: (err) {
      _handleError(err);
    });
  }

  void _handleError(Object err) {
    ref.read(notificationProvider.notifier).showInformation(err.toString());
  }

  void _handleOrderUpdate() {
    final navProvider = ref.read(navigationProvider.notifier);
    final notifProvider = ref.read(notificationProvider.notifier);

    switch (state.action) {
      case Action.newOrder:
        navProvider.go('/order_confirmed/${state.requestId!}');
        break;
      case Action.payInvoice:
        navProvider.go('/pay_invoice/${state.requestId!}');
        break;
      case Action.outOfRangeSatsAmount:
        notifProvider.showInformation('Sats out of range');
        break;
      case Action.outOfRangeFiatAmount:
        notifProvider.showInformation('Fiant amount out of range');
        break;
      case Action.waitingSellerToPay:
        notifProvider.showInformation('Waiting Seller to pay');
        break;
      case Action.waitingBuyerInvoice:
        notifProvider.showInformation('Waiting Buy Invoice');
        break;
      case Action.buyerTookOrder:
        notifProvider.showInformation('Buyer took order');
        break;
      case Action.fiatSentOk:
      case Action.holdInvoicePaymentSettled:
      case Action.rate:
      case Action.rateReceived:
      case Action.canceled:
      case Action.cooperativeCancelInitiatedByYou:
      case Action.disputeInitiatedByYou:
      case Action.adminSettled:
      default:
        notifProvider.showInformation(state.action.toString());
        break;
    }
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    super.dispose();
  }
}
