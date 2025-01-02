import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/repositories/mostro_repository.dart';
import 'package:mostro_mobile/shared/providers/navigation_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/notification_notifier_provider.dart';

class AddOrderNotifier extends StateNotifier<MostroMessage> {
  final MostroRepository _orderRepository;
  final Ref ref;
  final String uuid;
  StreamSubscription<MostroMessage>? _orderSubscription;

  AddOrderNotifier(this._orderRepository, this.uuid, this.ref)
      : super(MostroMessage<Order>(action: Action.newOrder));

  Future<void> submitOrder(String fiatCode, int fiatAmount, int satsAmount,
      String paymentMethod, OrderType orderType,
      {String? lnAddress}) async {
    final order = Order(
      fiatAmount: fiatAmount,
      fiatCode: fiatCode,
      kind: orderType,
      paymentMethod: paymentMethod,
      buyerInvoice: lnAddress,
    );
    final message =
        MostroMessage<Order>(action: Action.newOrder, id: null, payload: order);

    try {
      final stream = await _orderRepository.publishOrder(message);
      _orderSubscription = stream.listen((order) {
        state = order;
        _handleOrderUpdate();
      });
    } catch (e) {
      _handleError(e);
    }
  }

  void _handleError(Object err) {
    ref.read(notificationProvider.notifier).showInformation(err.toString());
  }

  void _handleOrderUpdate() {
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
    print('Disposed!');
    super.dispose();
  }
}
