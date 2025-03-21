import 'dart:async';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/peer.dart';
import 'package:mostro_mobile/features/order/notfiers/abstract_order_notifier.dart';

class OrderNotifier extends AbstractOrderNotifier {
  OrderNotifier(super.mostroService, super.orderId, super.ref);

  Future<void> sync() async {
    state = await mostroService.getOrderById(orderId) ?? state;
    state.payload is Order ? order = state.getPayload<Order>() : null;
    state.payload is Peer ? peer = state.getPayload<Peer>() : null;
  }

  Future<void> resubscribe() async {
    await sync();
    final session = mostroService.getSessionByOrderId(orderId);
    final stream = mostroService.subscribe(session!);
    await subscribe(stream);
  }

  Future<void> submitOrder(Order order) async {
    final message = MostroMessage<Order>(
      action: Action.newOrder,
      id: null,
      payload: order,
    );
    final session = await mostroService.publishOrder(message);
    final stream = mostroService.subscribe(session);
    await subscribe(stream);
  }

  Future<void> takeSellOrder(
      String orderId, int? amount, String? lnAddress) async {
    final session = await mostroService.takeSellOrder(
      orderId,
      amount,
      lnAddress,
    );
    final stream = mostroService.subscribe(session);
    await subscribe(stream);
  }

  Future<void> takeBuyOrder(String orderId, int? amount) async {
    final session = await mostroService.takeBuyOrder(
      orderId,
      amount,
    );
    final stream = mostroService.subscribe(session);
    await subscribe(stream);
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
}
