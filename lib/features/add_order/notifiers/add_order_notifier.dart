import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/repositories/mostro_repository.dart';
import 'package:mostro_mobile/features/add_order/screens/order_confirmation_screen.dart';
import 'package:mostro_mobile/features/take_order/screens/pay_lightning_invoice_screen.dart';
import 'package:mostro_mobile/shared/providers/navigation_notifier_provider.dart';

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
    final navProvider = ref.read(navigationProvider.notifier);

    print(state.action);

    switch (state.action) {
      case Action.newOrder:
        navProvider.navigate((context) {
          return OrderConfirmationScreen(orderId: state.requestId!);
        });
        break;
      case Action.payInvoice:
        navProvider.navigate((context) {
          return PayLightningInvoiceScreen(event: state);
        });
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
    print('Disposed!');
    super.dispose();
  }
}
