import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/shared/providers.dart';
import 'package:mostro_mobile/features/order/notfiers/abstract_mostro_notifier.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/services/mostro_service.dart';

class AddOrderNotifier extends AbstractMostroNotifier {
  late final MostroService mostroService;
  late int requestId;

  AddOrderNotifier(super.orderId, super.ref) {
    mostroService = ref.read(mostroServiceProvider);
    requestId = _requestIdFromOrderId(orderId);
    subscribe();
  }

  int _requestIdFromOrderId(String orderId) {
    final uuid = orderId.replaceAll('-', '');
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return (int.parse(uuid.substring(0, 8), radix: 16) ^ timestamp) &
        0x7FFFFFFF;
  }

  @override
  void subscribe() {
    subscription = ref.listen(
      addOrderEventsProvider(requestId),
      (_, next) {
        next.when(
          data: (msg) {
            if (msg != null) {
              if (msg.payload is Order) {
                if (msg.action == Action.newOrder) {
                  _confirmOrder(msg);
                } else {
                  logger.i('AddOrderNotifier: received ${msg.action}');
                }
              } else if (msg.payload is CantDo) {
                // Cancel timer on ANY response from Mostro
                AbstractMostroNotifier.cancelSessionTimeoutCleanupForRequestId(requestId);
                
                unawaited(handleEvent(msg));
                
                // Reset for retry if out_of_range_sats_amount or invalid_fiat_currency
                final cantDo = msg.getPayload<CantDo>();
                if (cantDo?.cantDoReason == CantDoReason.outOfRangeSatsAmount) {
                  _resetForRetry();
                } else if (cantDo?.cantDoReason == CantDoReason.invalidFiatCurrency) {
                  _cleanupSessionAndNavigateBack();
                }
              }
            }
          },
          error: (error, stack) => handleError(error, stack),
          loading: () {},
        );
      },
    );
  }

  Future<void> _confirmOrder(MostroMessage message) async {
    // Cancel timeout timer - order was successfully created
    AbstractMostroNotifier.cancelSessionTimeoutCleanupForRequestId(requestId);
    
    state = state.updateWith(message);
    session.orderId = message.id;
    ref.read(sessionNotifierProvider.notifier).saveSession(session);
    ref.read(orderNotifierProvider(message.id!).notifier).subscribe();
    ref.read(navigationProvider.notifier).go(
          '/order_confirmed/${message.id!}',
        );
    ref.invalidateSelf();
  }

  Future<void> submitOrder(Order order) async {
    final message = MostroMessage<Order>(
      action: Action.newOrder,
      id: null,
      requestId: requestId,
      payload: order,
    );
    final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
    session = await sessionNotifier.newSession(
      requestId: requestId,
      role: order.kind == OrderType.buy ? Role.buyer : Role.seller,
    );
    
    // Start 10s timeout cleanup timer for create orders
    AbstractMostroNotifier.startSessionTimeoutCleanupForRequestId(requestId, ref);
    
    await mostroService.submitOrder(message);
    state = state.updateWith(message);
  }

  /// Reset notifier state for retry after out_of_range_sats_amount error
  void _resetForRetry() {
    logger.i('Resetting AddOrderNotifier for retry after out_of_range_sats_amount');
    
    // Generate new requestId for next attempt
    requestId = _requestIdFromOrderId(orderId);
    
    // Reset state to initial clean state
    state = OrderState(
      action: Action.newOrder,
      status: Status.pending,
      order: null,
    );
    
    // Re-subscribe with new requestId
    subscription?.close();
    subscribe();
  }

  /// Clean up session and navigate back for invalid_fiat_currency error
  void _cleanupSessionAndNavigateBack() {
    logger.i('Cleaning up session and navigating back after invalid_fiat_currency');
    
    // Delete the session from SessionNotifier
    ref.read(sessionNotifierProvider.notifier).deleteSessionByRequestId(requestId);
    
    // Navigate back to home/order book
    ref.read(navigationProvider.notifier).go('/');
    
    // Invalidate this provider to clean up
    ref.invalidateSelf();
  }
  
  @override
  void dispose() {
    // Cancel timer for requestId when notifier is disposed
    AbstractMostroNotifier.cancelSessionTimeoutCleanupForRequestId(requestId);
    super.dispose();
  }
}
