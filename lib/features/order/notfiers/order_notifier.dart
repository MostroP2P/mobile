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
    try {
      final storage = ref.read(mostroStorageProvider);
      final messages = await storage.getAllMessagesForOrderId(orderId);
      if (messages.isEmpty) {
        logger.w('No messages found for order $orderId');
        return;
      }
      messages.sort((a, b) {
        final timestampA = a.timestamp ?? 0;
        final timestampB = b.timestamp ?? 0;
        return timestampA.compareTo(timestampB);
      });
      OrderState currentState = state;
      for (final message in messages) {
        if (message.action != Action.cantDo) {
          currentState = currentState.updateWith(message);
        }
      }
      state = currentState;
      logger.i(
          'Synced order $orderId to state: ${state.status} - ${state.action}');
    } catch (e, stack) {
      logger.e(
        'Error syncing order state for $orderId',
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
