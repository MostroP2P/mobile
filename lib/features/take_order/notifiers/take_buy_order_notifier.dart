import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/repositories/mostro_repository.dart';
import 'package:mostro_mobile/features/take_order/screens/pay_lightning_invoice_screen.dart';
import 'package:mostro_mobile/providers/event_store_providers.dart';

class TakeBuyOrderNotifier extends StateNotifier<MostroMessage> {
  final MostroRepository _orderRepository;
  final String orderId;
  final Ref ref;
  StreamSubscription<MostroMessage>? _orderSubscription;

  TakeBuyOrderNotifier(this._orderRepository, this.orderId, this.ref)
      : super(MostroMessage(action: Action.takeBuy));

  void takeBuyOrder(String orderId, int? amount) async {
    try {
      final stream = await _orderRepository.takeBuyOrder(orderId, amount);
      _orderSubscription = stream.listen((order) {
        state = order;
        _handleOrderUpdate();
      });
    } catch (e) {

    }
  }

  void _handleOrderUpdate() {
        final notificationProvider = ref.read(globalNotificationProvider.notifier);

    switch (state.action) {
      case Action.payInvoice:
        notificationProvider.showScreen(
            (context) => PayLightningInvoiceScreen(event: state));
        break;
      case Action.waitingBuyerInvoice:
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    super.dispose();
  }
}
