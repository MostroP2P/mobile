import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/repositories/mostro_repository.dart';

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
    switch (state.action) {
      case Action.payInvoice:
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
