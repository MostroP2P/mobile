import 'dart:async';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/shared/providers.dart';
import 'package:mostro_mobile/features/order/notfiers/abstract_mostro_notifier.dart';
import 'package:mostro_mobile/services/mostro_service.dart';

class OrderNotifier extends AbstractMostroNotifier {
  late final MostroService mostroService;

  OrderNotifier(super.orderId, super.ref) {
    mostroService = ref.read(mostroServiceProvider);
    sync();
    subscribe();
  }

  Future<void> sync() async {
    try {
      final storage = ref.read(mostroStorageProvider);
      final messages = await storage.getAllMessagesForOrderId(orderId);
      for (final msg in messages) {
        state = state.updateWith(msg);
      }
    } catch (e, stack) {
      logger.e(
        'Error syncing order state',
        error: e,
        stackTrace: stack,
      );
    }
  }

  Future<void> takeSellOrder(
      String orderId, int? amount, String? lnAddress) async {
    final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
    session = await sessionNotifier.newSession(
      orderId: orderId,
      role: Role.buyer,
    );
    mostroService.subscribe(session.tradeKey);
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
      role: Role.seller,
    );
    mostroService.subscribe(session.tradeKey);
    await mostroService.takeBuyOrder(
      orderId,
      amount,
    );
  }

  Future<void> sendInvoice(
    String orderId,
    String invoice,
    int? amount,
  ) async {
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
