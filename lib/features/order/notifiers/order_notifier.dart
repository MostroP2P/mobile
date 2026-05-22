import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';
import 'package:mostro_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:mostro_mobile/shared/providers.dart';
import 'package:mostro_mobile/features/order/notifiers/abstract_mostro_notifier.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/services/mostro_service.dart';

class OrderNotifier extends AbstractMostroNotifier {
  late final MostroService mostroService;
  ProviderSubscription<AsyncValue<List<NostrEvent>>>? _publicEventsSubscription;
  bool _isSyncing = false; // Only for sync() method
  
  OrderNotifier(super.orderId, super.ref) {
    mostroService = ref.read(mostroServiceProvider);
    sync();
    subscribe();
    _subscribeToPublicEvents();
  }

  @override
  Future<void> handleEvent(MostroMessage event,
      {bool bypassTimestampGate = false, Status? previousStatus}) async {
    logger.i('OrderNotifier received event: ${event.action} for order $orderId');

    // Handle the event normally - timeout/cancellation logic is now in AbstractMostroNotifier
    await super.handleEvent(event,
        bypassTimestampGate: bypassTimestampGate,
        previousStatus: previousStatus);
  }

  Future<void> sync() async {
    if (_isSyncing) return;

    try {
      _isSyncing = true;

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

      // Restart-resilient cleanup: a canceled bonded order whose in-memory
      // grace timer was lost when the app closed would otherwise stay an
      // orphan in My Trades and block retaking.
      if (state.status == Status.canceled) {
        await reconcileCanceledBondedSession();
      }
    } catch (e, stack) {
      logger.e(
        'Error syncing order state for $orderId',
        error: e,
        stackTrace: stack,
      );
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> takeSellOrder(
      String orderId, int? amount, String? lnAddress) async {
    final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
    session = await sessionNotifier.newSession(
      orderId: orderId,
      role: Role.buyer,
    );

    // Drop any stale grace timer/flag from a previous cycle on this order so
    // it can't delete the session we just created (retake within 60s).
    AbstractMostroNotifier.clearBondCancelDeletion(orderId);

    // Start 10s timeout cleanup timer for orphan session prevention
    AbstractMostroNotifier.startSessionTimeoutCleanup(orderId, ref);
    
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

    // Drop any stale grace timer/flag from a previous cycle on this order so
    // it can't delete the session we just created (retake within 60s).
    AbstractMostroNotifier.clearBondCancelDeletion(orderId);

    // Start 10s timeout cleanup timer for orphan session prevention
    AbstractMostroNotifier.startSessionTimeoutCleanup(orderId, ref);
    
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

  Future<void> sendBondPayoutInvoice(String invoice) async {
    await mostroService.sendBondPayoutInvoice(orderId, invoice);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outbound = MostroMessage(
      action: Action.addBondInvoice,
      id: orderId,
      payload: PaymentRequest(lnInvoice: invoice),
      timestamp: timestamp,
    );
    await ref.read(mostroStorageProvider).addMessage(
          'outbound_addBondInvoice_${orderId}_$timestamp',
          outbound,
        );
  }

  Future<void> cancelOrder() async {
    final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
    final currentSession = sessionNotifier.getSessionByOrderId(orderId);
    // A maker bond is still uncommitted; the daemon rejects an explicit cancel
    // while the order sits at WaitingMakerBond. Abandon locally instead — the
    // bond hold invoice expires server-side and the stranded order is deleted.
    if (currentSession?.bondPending == true) {
      await ref.read(mostroStorageProvider).deleteAllMessagesByOrderId(orderId);
      await sessionNotifier.deleteSession(orderId);
      return;
    }
    await mostroService.cancelOrder(orderId);
    // The cancel was sent by the user: its `canceled` response means the
    // bond is returned (no slash), so the session can be deleted immediately
    // instead of waiting for a bond-slashed notice that will never arrive.
    AbstractMostroNotifier.markUserInitiatedCancel(orderId);
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

  /// Update state from MostroMessage (used during restore)
  void updateStateFromMessage(MostroMessage message) {
    if (mounted) {
      state = state.updateWith(message);
    }
  }

  /// Set fiatWasSent flag (used during restore to provide context
  /// for cooperative cancel action remapping)
  void setFiatWasSent() {
    if (!mounted || state.fiatWasSent) return;
    state = state.copyWith(fiatWasSent: true);
  }

  /// Update dispute in state (used during restore)
  void updateDispute(Dispute dispute) {
    if (mounted) {
      state = state.copyWith(dispute: dispute);
    }
  }

  /// Subscribe to public events (38383) to detect automatic order cancellation
  void _subscribeToPublicEvents() {
    _publicEventsSubscription = ref.listen(
      orderEventsProvider,
      (_, next) async {
        try {
          // Only detect automatic cancellation for pending orders
          final publicEvent = ref.read(eventProvider(orderId));
          final currentSession = ref.read(sessionProvider(orderId));
          
          if (publicEvent?.status == Status.canceled && 
              state.status == Status.pending &&
              currentSession != null) {
            
            logger.i('AUTOMATIC EXPIRATION: Order $orderId expired, removing from My Trades');
            
            // Delete session - order disappears from My Trades
            final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
            await sessionNotifier.deleteSession(orderId);
            
            // Persist expiration in notification history (and show SnackBar)
            final notifProvider = ref.read(notificationActionsProvider.notifier);
            await notifProvider.notify(
              Action.canceled,
              values: {'previous_status': Status.pending.value},
              orderId: orderId,
            );

            ref.invalidateSelf();
          }
        } catch (e, stack) {
          logger.e(
            'Error handling automatic cancellation for order $orderId',
            error: e,
            stackTrace: stack,
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _publicEventsSubscription?.close();
    super.dispose();
  }

}
