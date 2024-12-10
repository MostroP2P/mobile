import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/repositories/mostro_repository.dart';
import 'package:mostro_mobile/providers/event_store_providers.dart';

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
    final message = MostroMessage<Order>(
        action: Action.newOrder, requestId: null, payload: order);

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
    print(err);
  }

  void _handleOrderUpdate() {
    final notificationProvider = ref.read(globalNotificationProvider.notifier);

    switch (state.action) {
      case Action.newOrder:
        notificationProvider.showNotification(state, () {});
        break;
      case Action.outOfRangeSatsAmount:
      case Action.outOfRangeFiatAmount:
        break;
      default:
        // Handle other actions if necessary
        break;
    }
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    super.dispose();
  }
}
