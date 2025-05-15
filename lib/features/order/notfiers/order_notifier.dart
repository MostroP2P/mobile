import 'dart:async';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/shared/providers.dart';
import 'package:mostro_mobile/features/order/notfiers/abstract_mostro_notifier.dart';
import 'package:mostro_mobile/services/mostro_service.dart';

class OrderNotifier extends AbstractMostroNotifier {
  late final MostroService mostroService;

  late Order order;

  OrderNotifier(super.orderId, super.ref) {
    mostroService = ref.read(mostroServiceProvider);
    sync();
    subscribe();
  }

  Future<void> sync() async {
    final storage = ref.read(mostroStorageProvider);
    final latestOrder =
        await storage.getLatestMessageOfTypeById<Order>(orderId);
    if (latestOrder != null) {
      order = latestOrder.getPayload<Order>()!;
      status = order.status;
    }
    final newState = await storage.getLatestMessageById(orderId);
    if (newState != null) {
      state = newState;
    }
  }

  Future<void> takeSellOrder(
      String orderId, int? amount, String? lnAddress) async {
    final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
    session = await sessionNotifier.newSession(
      orderId: orderId,
      role: order.kind == OrderType.buy ? Role.buyer : Role.seller,
    );
    mostroService.subscribe(session);
    await mostroService.takeSellOrder(
      orderId,
      amount,
      lnAddress,
    );
  }

  Future<void> takeBuyOrder(String orderId, int? amount) async {
    final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
    session = await sessionNotifier.newSession(
      orderId: orderId,
      role: order.kind == OrderType.buy ? Role.buyer : Role.seller,
    );
    mostroService.subscribe(session);
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

}
