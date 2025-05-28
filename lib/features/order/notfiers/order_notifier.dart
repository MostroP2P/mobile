import 'dart:async';
import 'package:collection/collection.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';
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
    final storage = ref.read(mostroStorageProvider);
    final messages = await storage.getAllMessagesForOrderId(orderId);
    if (messages.isEmpty) {
      return;
    }
    final msg = messages.firstWhereOrNull((m) => m.action != Action.cantDo);
    if (msg?.payload is Order) {
      state = OrderState(
        status: msg!.getPayload<Order>()!.status,
        action: msg.action,
        order: msg.getPayload<Order>()!,
      );
    } else {
      final orderMsg = await storage.getLatestMessageOfTypeById<Order>(orderId);
      if (orderMsg != null) {
        state = OrderState(
          status: orderMsg.getPayload<Order>()!.status,
          action: orderMsg.action,
          order: orderMsg.getPayload<Order>()!,
        );
      }
    }
  }

  Future<void> takeSellOrder(
      String orderId, int? amount, String? lnAddress) async {
    final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
    session = await sessionNotifier.newSession(
      orderId: orderId,
      role: Role.buyer,
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
      role: Role.seller,
    );
    mostroService.subscribe(session);
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
