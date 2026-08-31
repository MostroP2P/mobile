import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';
import 'package:mostro_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:mostro_mobile/shared/providers.dart';
import 'package:mostro_mobile/features/order/notifiers/abstract_mostro_notifier.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/services/mostro_service.dart';
import 'package:mostro_mobile/shared/utils/order_sync_helpers.dart';

class OrderNotifier extends AbstractMostroNotifier {
  late final MostroService mostroService;
  ProviderSubscription<NostrEvent?>? _publicEventsSubscription;
  bool _isSyncing = false; // Only for sync() method
  bool _hydrated = false; // A sync() has read the history successfully
  bool _resyncRequested = false; // A sync() was asked for while one was running

  /// Replays chained within the current recovery generation.
  @visibleForTesting
  int resyncAttempts = 0;

  /// Bounds the chain of replays a single startup may schedule. Rejected
  /// resolutions are hostile input, so the chain must not be paced by how fast
  /// they arrive.
  static const _maxChainedResyncs = 3;

  OrderNotifier(super.orderId, super.ref) {
    mostroService = ref.read(mostroServiceProvider);
    sync();
    subscribe();
    _subscribeToPublicEvents();
  }

  @override
  Future<void> handleEvent(MostroMessage event,
      {bool bypassTimestampGate = false,
      Status? previousStatus,
      bool wasUserInitiatedCancel = false}) async {
    logger.i('OrderNotifier received event: ${event.action} for order $orderId');

    // Handle the event normally - timeout/cancellation logic is now in AbstractMostroNotifier
    await super.handleEvent(event,
        bypassTimestampGate: bypassTimestampGate,
        previousStatus: previousStatus,
        wasUserInitiatedCancel: wasUserInitiatedCancel);
  }

  /// Replays the persisted history when a resolution was rejected only because
  /// startup had not loaded its dispute yet. Once hydrated, a rejection is the
  /// correct outcome and no replay is needed — which also keeps forged
  /// resolutions from each costing a full storage read.
  @override
  void onAdminResolutionRejected(MostroMessage message) {
    if (_hydrated) return;
    logger.i(
        'Re-syncing order $orderId: ${message.action} arrived before hydration completed');

    // The cap bounds one contiguous replay chain, not the notifier's lifetime.
    // A rejection arriving outside a running pass is a new recovery generation
    // and gets a fresh budget: otherwise an exhausted counter would strand
    // every later resolution, since the queued replay that would have picked
    // up the just-persisted message is the one being refused.
    if (!_isSyncing) resyncAttempts = 0;

    sync();
  }

  Future<void> sync() async {
    if (_isSyncing) {
      _resyncRequested = true;
      return;
    }

    var succeeded = false;
    try {
      _isSyncing = true;

      final storage = ref.read(mostroStorageProvider);
      final messages = await storage.getAllMessagesForOrderId(orderId);
      if (messages.isEmpty) {
        logger.w('No messages found for order $orderId');
        succeeded = true;
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

      // A replay that lands on the same values notifies nobody:
      // AbstractMostroNotifier.updateShouldNotify compares by value.
      state = currentState;

      logger.i(
          'Synced order $orderId to state: ${state.status} - ${state.action}');

      // Restart-resilient cleanup: a canceled bonded order whose in-memory
      // grace timer was lost when the app closed would otherwise stay an
      // orphan in My Trades and block retaking.
      if (state.status == Status.canceled) {
        await reconcileCanceledBondedSession();
      }
      succeeded = true;
    } catch (e, stack) {
      logger.e(
        'Error syncing order state for $orderId',
        error: e,
        stackTrace: stack,
      );
    } finally {
      _isSyncing = false;

      final completion = resolveSyncCompletion(
        succeeded: succeeded,
        resyncRequested: _resyncRequested,
        resyncAttempts: resyncAttempts,
        maxChainedResyncs: _maxChainedResyncs,
      );
      _resyncRequested = false;

      switch (completion) {
        case SyncCompletion.replay:
          resyncAttempts++;
          sync();
        case SyncCompletion.hydrated:
          _hydrated = true;
        case SyncCompletion.unhydrated:
          break;
      }
    }
  }

  Future<void> takeSellOrder(
      String orderId, int? amount, String? lnAddress) async {
    // Serialize session creation + publish with the restore reset behind the
    // shared session lock so the new session can't be wiped by a concurrent
    // restore (TOCTOU-safe). See [SessionLifecycleLock].
    await ref.read(sessionLifecycleLockProvider).withSessionLock(() async {
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
    });
  }

  Future<void> takeBuyOrder(String orderId, int? amount) async {
    // Serialize session creation + publish with the restore reset behind the
    // shared session lock so the new session can't be wiped by a concurrent
    // restore (TOCTOU-safe). See [SessionLifecycleLock].
    await ref.read(sessionLifecycleLockProvider).withSessionLock(() async {
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
    });
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
    // Flag this cancel as user-initiated so the upcoming Action.canceled
    // response is not misattributed to counterparty inactivity when the
    // order is in waiting-payment / waiting-buyer-invoice. Roll back the
    // flag if the outbound request fails, otherwise a future canceled event
    // for the same orderId would be misclassified as user-initiated.
    AbstractMostroNotifier.markUserInitiatedCancel(orderId);
    try {
      await mostroService.cancelOrder(orderId);
    } catch (_) {
      AbstractMostroNotifier.unmarkUserInitiatedCancel(orderId);
      rethrow;
    }
  }

  Future<void> sendFiatSent() async {
    // Range orders prepare a child session for the remainder via
    // _prepareChildOrderIfNeeded -> createChildOrderSession. Serialize that
    // creation + publish with the restore reset behind the shared session lock
    // so a concurrent restore can't wipe the child session (TOCTOU-safe).
    await ref.read(sessionLifecycleLockProvider).withSessionLock(() async {
      await mostroService.sendFiatSent(orderId);
    });
  }

  Future<void> releaseOrder() async {
    // Same child-session protection as sendFiatSent (range-order remainder).
    await ref.read(sessionLifecycleLockProvider).withSessionLock(() async {
      await mostroService.releaseOrder(orderId);
    });
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
    // Listen to this order's own public event: listening to the whole book
    // made every notifier run this callback for every incoming public event.
    _publicEventsSubscription = ref.listen(
      eventProvider(orderId),
      (_, publicEvent) async {
        try {
          // Only detect automatic cancellation for pending orders
          final currentSession = ref.read(sessionProvider(orderId));
          
          if (publicEvent?.status == Status.canceled && 
              state.status == Status.pending &&
              currentSession != null) {
            
            logger.i('AUTOMATIC EXPIRATION: Order $orderId expired, removing from My Trades');
            
            // Delete session - order disappears from My Trades
            final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
            await sessionNotifier.deleteSession(orderId);
            
            // Persist expiration in notification history (and show SnackBar).
            // Use a stable eventId so repeated public-event emissions for the
            // same auto-expiration are deduplicated by the notifications store.
            final notifProvider = ref.read(notificationActionsProvider.notifier);
            await notifProvider.notify(
              Action.canceled,
              values: {'previous_status': Status.pending.value},
              orderId: orderId,
              eventId: 'auto_expire:$orderId',
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
