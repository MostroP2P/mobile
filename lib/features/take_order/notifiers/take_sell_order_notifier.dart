import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/repositories/mostro_repository.dart';
import 'package:mostro_mobile/providers/event_store_providers.dart';

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

  void _handleError(Object err) {}

  void sendInvoice(String orderId, String invoice, int amount) async {
    await _orderRepository.sendInvoice(orderId, invoice);
  }

  void _handleOrderUpdate() {
    final notificationProvider = ref.read(globalNotificationProvider.notifier);

    switch (state.action) {
      case Action.addInvoice:
      case Action.waitingSellerToPay:
	  case Action.outOfRangeFiatAmount:
	  case Action.outOfRangeSatsAmount:
        break;
      default:
        notificationProvider.showNotification(state, () {});
        break;
    }
  }

  void cancelOrder() {
    //state = state.copyWith(status: TakeSellOrderStatus.cancelled);
    dispose();
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    super.dispose();
  }
}
