import 'dart:async';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/features/order/notfiers/abstract_mostro_notifier.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/services/mostro_service.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';

class OrderNotifier extends AbstractMostroNotifier {
  late final MostroService mostroService;

  OrderNotifier(super.orderId, super.ref) {
    mostroService = ref.read(mostroServiceProvider);
    sync();
    subscribe();
  }


  @override
  void handleEvent(MostroMessage event) {
    // Forward all messages so UI reacts to CantDo, Peer, PaymentRequest, etc.
    state = event;
    handleOrderUpdate();
  }

  Future<void> submitOrder(Order order) async {
    final message = MostroMessage<Order>(
      action: Action.newOrder,
      id: null,
      payload: order,
    );
    await mostroService.submitOrder(message);
  }

  Future<void> takeSellOrder(
      String orderId, int? amount, String? lnAddress) async {
    await mostroService.takeSellOrder(
      orderId,
      amount,
      lnAddress,
    );
  }

  Future<void> takeBuyOrder(String orderId, int? amount) async {
    await mostroService.takeBuyOrder(
      orderId,
      amount,
    );
  }

  Future<void> sendInvoice(String orderId, String invoice, int? amount) async {
    await mostroService.sendInvoice(
      orderId,
      invoice,
      amount,
    );
  }

  Future<void> cancelOrder() async {
    await mostroService.cancelOrder(orderId);
  }

  Future<void> sendFiatSent() async {
    await mostroService.sendFiatSent(orderId);
  }

  Future<void> releaseOrder() async {
    await mostroService.releaseOrder(orderId);
  }

  Future<void> disputeOrder() async {
    await mostroService.disputeOrder(orderId);
  }

  Future<void> submitRating(int rating) async {
    await mostroService.submitRating(
      orderId,
      rating,
    );
  }

  @override
  void dispose() {
    ref.read(cantDoNotifierProvider(orderId).notifier).dispose();
    ref.read(paymentNotifierProvider(orderId).notifier).dispose();
    ref.read(disputeNotifierProvider(orderId).notifier).dispose();
    super.dispose();
  }
}
