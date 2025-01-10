import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/repositories/mostro_repository.dart';
import 'package:mostro_mobile/shared/providers/navigation_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/notification_notifier_provider.dart';

class TakeSellOrderNotifier extends StateNotifier<MostroMessage> {
  final MostroRepository _orderRepository;
  final String orderId;
  final Ref ref;
  StreamSubscription<MostroMessage>? _orderSubscription;

  TakeSellOrderNotifier(this._orderRepository, this.orderId, this.ref)
      : super(MostroMessage<Order>(action: Action.takeSell));

  void takeSellOrder(String orderId, int? amount, String? lnAddress) async {
    try {
      final stream =
          await _orderRepository.takeSellOrder(orderId, amount, lnAddress);
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

  void sendInvoice(String orderId, String invoice, int? amount) async {
    await _orderRepository.sendInvoice(orderId, invoice);
  }

  void _handleOrderUpdate() {
    final navProvider = ref.read(navigationProvider.notifier);
    final notifProvider = ref.read(notificationProvider.notifier);
    switch (state.action) {
      case Action.addInvoice:
        navProvider.go('/add_invoice/$orderId');
        break;
      case Action.waitingSellerToPay:
        navProvider.go('/');
        notifProvider.showInformation('Waiting for Seller to pay');
      case Action.incorrectInvoiceAmount:
        notifProvider.showInformation('Incorrect Invoice Amount');
        break;
      case Action.outOfRangeFiatAmount:
      case Action.outOfRangeSatsAmount:
        break;
      case Action.holdInvoicePaymentAccepted:
        break;
      case Action.fiatSentOk:
        break;
      case Action.released:
        break;
      case Action.purchaseCompleted:
        break;
      case Action.rate:
        break;
      case Action.cooperativeCancelInitiatedByPeer:
      case Action.disputeInitiatedByPeer:
      case Action.adminSettled:
      default:
        notifProvider.showInformation(state.action.toString());
        break;
    }
  }

  void cancelOrder() {
    dispose();
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    super.dispose();
  }
}
