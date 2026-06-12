import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/features/mostro/mostro_instance.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';
import 'package:mostro_mobile/features/restore/restore_mode_provider.dart';
import 'package:mostro_mobile/shared/providers.dart';
import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:mostro_mobile/features/notifications/utils/notification_data_extractor.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/shared/utils/bond_cancel_helpers.dart';
import 'package:mostro_mobile/shared/utils/bond_payout_helpers.dart';

class AbstractMostroNotifier extends StateNotifier<OrderState> {
  final String orderId;
  final Ref ref;

  late Session session;

  ProviderSubscription<AsyncValue<MostroMessage?>>? subscription;
  final Set<String> _processedEventIds = <String>{};

  // Timer storage for orphan session cleanup
  static final Map<String, Timer> _sessionTimeouts = {};

  // Deferred session deletion for canceled bonded orders, so a trailing
  // bond-slashed notice can still be received before the trade key is dropped.
  static final Map<String, Timer> _bondCancelDeletionTimers = {};

  // Orders the user explicitly asked to cancel. Serves two purposes: a
  // voluntary cancel returns the taker's bond (no slash, so no trailing
  // bond-slashed), letting its `canceled` response delete the session
  // immediately instead of deferring 60s; and it lets the notification path
  // distinguish a user cancel from a counterparty inactivity timeout, which
  // uses the same Action.canceled. Consumed once per cancel in subscribe().
  static final Set<String> _userInitiatedCancels = <String>{};

  /// Marks an order as cancelled by the user, so the matching `canceled`
  /// response is treated as a voluntary cancel (immediate session deletion)
  /// and notified as user-initiated rather than a counterparty timeout.
  @protected
  static void markUserInitiatedCancel(String orderId) {
    _userInitiatedCancels.add(orderId);
  }

  /// Clears the user-initiated cancel flag for [orderId]. Used to roll back
  /// the marker when the outbound cancel request fails so a later, unrelated
  /// Action.canceled is not misclassified as user-initiated.
  static void unmarkUserInitiatedCancel(String orderId) {
    _userInitiatedCancels.remove(orderId);
  }

  AbstractMostroNotifier(
    this.orderId,
    this.ref, {
    OrderState? initialState,
  }) : super(initialState ??
            OrderState(
              action: Action.newOrder,
              status: Status.pending,
              order: null,
            )) {
    final oldSession =
        ref.read(sessionNotifierProvider.notifier).getSessionByOrderId(orderId);
    if (oldSession != null) {
      session = oldSession;
    }
  }

  void subscribe() {
    subscription = ref.listen(
      mostroMessageStreamProvider(orderId),
      (_, next) {
        next.when(
          data: (MostroMessage? msg) {
            // Skip all old message processing during restore - messages are saved but state is not updated
            final isRestoring = ref.read(isRestoringProvider);
            if (isRestoring) {
              logger.d(
                  'Skipping old message processing during restore: ${msg?.action}');
              return;
            }

            if (kDebugMode) {
              logger.i('Received message: ${msg?.toJson()}');
            } else {
              logger.i('Received message with action: ${msg?.action}');
            }
            if (msg != null) {
              // Cancel timer on ANY response from Mostro for this order
              cancelSessionTimeoutCleanup(orderId);

              // Capture previous status before updating state, so downstream
              // notification handlers can differentiate messages (e.g. show a
              // counterparty-specific cancellation reason).
              final previousStatus = state.status;

              // Consume the user-initiated cancel flag (set by cancelOrder)
              // so Action.canceled responses can be distinguished from
              // counterparty inactivity timeouts, which use the same action.
              final wasUserInitiatedCancel = msg.action == Action.canceled &&
                  _userInitiatedCancels.remove(orderId);

              if (mounted) {
                state = state.updateWith(msg);
              }
              if (msg.timestamp != null &&
                  msg.timestamp! >
                      DateTime.now()
                          .subtract(const Duration(seconds: 60))
                          .millisecondsSinceEpoch) {
                logger.i(
                    'Message timestamp check passed, calling handleEvent for ${msg.action}');
                unawaited(handleEvent(msg,
                    previousStatus: previousStatus,
                    wasUserInitiatedCancel: wasUserInitiatedCancel));
              } else {
                logger.w(
                    'Message timestamp check failed for ${msg.action}. Timestamp: ${msg.timestamp}, Current: ${DateTime.now().millisecondsSinceEpoch}, Threshold: ${DateTime.now().subtract(const Duration(seconds: 60)).millisecondsSinceEpoch}');

                // Handle dispute actions even if timestamp is old, since they're critical for UI state
                // but bypass navigation/notification side effects
                if (msg.action == Action.disputeInitiatedByPeer ||
                    msg.action == Action.disputeInitiatedByYou) {
                  logger.i(
                      'Processing dispute action ${msg.action} despite old timestamp (state update only)');
                  unawaited(handleEvent(msg,
                      bypassTimestampGate: true,
                      previousStatus: previousStatus,
                      wasUserInitiatedCancel: wasUserInitiatedCancel));
                }
              }
            }
          },
          error: (error, stack) {
            handleError(error, stack);
          },
          loading: () {},
        );
      },
    );
  }

  void handleError(Object err, StackTrace stack) {
    logger.e(err);
  }

  void sendNotification(Action action,
      {Map<String, dynamic>? values,
      bool isTemporary = false,
      String? eventId}) {
    final notifProvider = ref.read(notificationActionsProvider.notifier);

    if (isTemporary) {
      notifProvider.showTemporary(action, values: values ?? {});
    } else {
      notifProvider.notify(action,
          values: values ?? {}, orderId: orderId, eventId: eventId);
    }
  }

  Future<void> handleEvent(MostroMessage event,
      {bool bypassTimestampGate = false,
      Status? previousStatus,
      bool wasUserInitiatedCancel = false}) async {
    // Skip if we've already processed this exact event
    final eventKey = '${event.id}_${event.action}_${event.timestamp}';
    if (_processedEventIds.contains(eventKey)) {
      logger.d('Skipping duplicate event: $eventKey');
      return;
    }
    _processedEventIds.add(eventKey);

    final navProvider = ref.read(navigationProvider.notifier);

    // Check if this is a recent event for notification/navigation purposes
    final isRecent = event.timestamp != null &&
        event.timestamp! >
            DateTime.now()
                .subtract(const Duration(seconds: 60))
                .millisecondsSinceEpoch;

    // Extract notification data using the centralized extractor
    final notificationData =
        await NotificationDataExtractor.extractFromMostroMessage(event, ref,
            session: session,
            previousStatus: previousStatus,
            wasUserInitiatedCancel: wasUserInitiatedCancel);

    // Only notify for recent events; old disputes still update state below
    if (notificationData != null && (isRecent || !bypassTimestampGate)) {
      sendNotification(
        notificationData.action,
        values: notificationData.values,
        isTemporary: notificationData.isTemporary,
        eventId: notificationData.eventId,
      );
    } else if (notificationData != null && bypassTimestampGate) {
      logger.i(
          'Skipping notification for old event: ${event.action} (timestamp: ${event.timestamp})');
    }

    /// Handle incoming events and update state accordingly
    logger.i(
        'handleEvent: Processing action ${event.action} for order $orderId (bypassTimestampGate: $bypassTimestampGate)');
    switch (event.action) {
      case Action.newOrder:
        // Check if Mostro is republishing the order after timeout
        final currentSession = ref.read(sessionProvider(orderId));
        if (currentSession != null &&
            (state.status == Status.waitingBuyerInvoice ||
                state.status == Status.waitingPayment)) {
          // This is a maker receiving order republication after taker timeout
          logger.i(
              'MAKER: Received order reactivation from Mostro - taker timed out, order returned to pending');

          // Show notification: counterpart didn't respond, order will be republished
          if (isRecent || !bypassTimestampGate) {
            final notifProvider =
                ref.read(notificationActionsProvider.notifier);
            notifProvider.showCustomMessage('orderTimeoutMaker');
          }
        }
        break;

      case Action.canceled:
        // Handle cancellation sent by Mostro (for both timeout and cancellation scenarios)
        final currentSession = ref.read(sessionProvider(orderId));
        if (currentSession != null) {
          logger.i(
              'CANCELLATION: Received cancellation message from Mostro for order $orderId');

          // A bond-slashed notice only follows a *timeout* slash, never a
          // voluntary cancel (the daemon returns the taker's bond). So defer
          // deletion only for a bonded order the user did NOT cancel itself;
          // otherwise delete immediately as before.
          final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
          // The flag was already consumed in subscribe() and propagated here
          // as wasUserInitiatedCancel; reuse it instead of removing again.
          if (shouldDeferBondCancelDeletion(
            userInitiated: wasUserInitiatedCancel,
            hadBond: await _orderHadBond(orderId),
          )) {
            _startBondCancelDeletion(orderId, ref);
            logger.i('Deferred session deletion for bonded order $orderId');
          } else {
            await sessionNotifier.deleteSession(orderId);
            logger.i('Session deleted for canceled order $orderId');
          }

          // SnackBar + history entry are delivered via the centralized
          // NotificationDataExtractor + notify() path above.

          // Navigate to main order book screen
          if (isRecent && !bypassTimestampGate) {
            navProvider.go('/');
          }

          return; // Cancellation handled; nothing else to process
        }
        break;

      case Action.bondSlashed:
        // The forfeiture notification was already persisted at the top of
        // handleEvent. The notice arrived, so cancel the deferred deletion
        // and release the session now.
        _bondCancelDeletionTimers.remove(orderId)?.cancel();
        await ref.read(sessionNotifierProvider.notifier).deleteSession(orderId);
        logger.i('Session deleted after bond-slashed for order $orderId');
        break;

      case Action.buyerTookOrder:
        final order = event.getPayload<Order>();
        if (order == null) {
          logger.e('Buyer took order, but order is null');
          break;
        }

        // Update session and state with correct peer based on session role
        final sessionProvider = ref.read(sessionNotifierProvider.notifier);

        // Re-fetch session to ensure it's initialized
        final fetchedSession = sessionProvider.getSessionByOrderId(orderId);
        if (fetchedSession == null) {
          logger.e('Session not found for order $orderId in buyerTookOrder');
          break;
        }
        session = fetchedSession;

        // Get the correct peer public key based on current user's role
        String? peerPubkey;
        if (session.role == Role.buyer) {
          // If I'm the buyer, the seller is my peer
          peerPubkey = order.sellerTradePubkey;
        } else if (session.role == Role.seller) {
          // If I'm the seller, the buyer is my peer
          peerPubkey = order.buyerTradePubkey;
        }

        final peer = peerPubkey != null ? Peer(publicKey: peerPubkey) : null;
        sessionProvider.updateSession(orderId, (s) => s.peer = peer);
        state = state.copyWith(peer: peer);

        // Enable chat and navigate
        final chat = ref.read(chatRoomsProvider(orderId).notifier);
        chat.subscribe();
        navProvider.go('/trade_detail/$orderId');
        break;

      case Action.payInvoice:
        if (event.payload is PaymentRequest) {
          navProvider.go('/pay_invoice/${event.id!}');
        }
        ref.read(sessionNotifierProvider.notifier).saveSession(session);
        break;

      case Action.payBondInvoice:
        if (event.payload is PaymentRequest) {
          navProvider.go('/pay_bond/${event.id!}');
        }
        // A maker bond is still uncommitted: keep it ephemeral (in memory only)
        // so an abandoned order never survives a restart. The taker bond and
        // the post-confirmation maker order persist normally.
        if (!session.bondPending) {
          ref.read(sessionNotifierProvider.notifier).saveSession(session);
        }
        break;

      case Action.addInvoice:
        final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
        sessionNotifier.saveSession(session);
        await _handleAddInvoiceWithAutoLightningAddress(event);
        break;

      case Action.addBondInvoice:
        final request = event.getPayload<BondPayoutRequest>();
        if (request == null) break;
        final instance = ref.read(orderRepositoryProvider).mostroInstance;
        final claimWindowDays = instance?.bondPayoutClaimWindowDays ?? 15;
        if (isBondClaimExpired(request.slashedAt, claimWindowDays)) break;
        ref.read(sessionNotifierProvider.notifier).saveSession(session);
        navProvider.go('/bond_payout/$orderId');
        break;

      case Action.holdInvoicePaymentAccepted:
        final order = event.getPayload<Order>();
        if (order == null) return;

        // Update session and state with correct peer based on session role
        final sessionProvider = ref.read(sessionNotifierProvider.notifier);

        // Re-fetch session to ensure it's initialized
        final fetchedSession = sessionProvider.getSessionByOrderId(orderId);
        if (fetchedSession == null) {
          logger.e(
              'Session not found for order $orderId in holdInvoicePaymentAccepted');
          break;
        }
        session = fetchedSession;

        // Get the correct peer public key based on current user's role
        String? peerPubkey;
        if (session.role == Role.buyer) {
          // If I'm the buyer, the seller is my peer
          peerPubkey = order.sellerTradePubkey;
        } else if (session.role == Role.seller) {
          // If I'm the seller, the buyer is my peer
          peerPubkey = order.buyerTradePubkey;
        }

        final peer = peerPubkey != null ? Peer(publicKey: peerPubkey) : null;
        sessionProvider.updateSession(orderId, (s) => s.peer = peer);
        state = state.copyWith(peer: peer);

        // Enable chat
        final chat = ref.read(chatRoomsProvider(orderId).notifier);
        chat.subscribe();

        // Check if Lightning address was used and show notification
        if (session.role == Role.buyer) {
          try {
            final storage = ref.read(mostroStorageProvider);
            final messages = await storage.getAllMessagesForOrderId(orderId);

            // Find the order confirmation message (incoming Action.newOrder)
            final orderConfirmation = messages
                .where((m) => m.action == Action.newOrder)
                .where((m) => m.getPayload<Order>()?.buyerInvoice != null)
                .firstOrNull;

            if (orderConfirmation != null) {
              final confirmationOrder = orderConfirmation.getPayload<Order>();
              final buyerInvoice = confirmationOrder?.buyerInvoice;

              if (buyerInvoice != null &&
                  _isValidLightningAddress(buyerInvoice)) {
                // Show Lightning address used notification
                final notificationNotifier =
                    ref.read(notificationActionsProvider.notifier);
                notificationNotifier.showCustomMessage('lightningAddressUsed');
              }
            }
          } catch (e) {
            logger.w('Error checking lightning address usage: $e');
            // Fail silently, don't affect main functionality
          }
        }
        break;

      case Action.holdInvoicePaymentSettled:
        navProvider.go('/trade_detail/$orderId');
        break;

      case Action.paymentFailed:
        // No additional logic needed beyond notification
        break;

      case Action.waitingSellerToPay:
        // Navigation logic
        final isUserCreator = _isUserCreator();
        final isBuyOrder = state.order?.kind == OrderType.buy;
        if (!(isUserCreator && isBuyOrder)) {
          navProvider.go('/trade_detail/$orderId');
        }
        break;

      case Action.waitingBuyerInvoice:
        // Navigation logic
        final isUserCreator = _isUserCreator();
        final isSellOrder = state.order?.kind == OrderType.sell;
        if (!(isUserCreator && isSellOrder)) {
          navProvider.go('/trade_detail/$orderId');
        }
        break;

      case Action.fiatSentOk:
        // The extractor already handles role filtering for fiatSentOk
        if (isRecent && !bypassTimestampGate) {
          navProvider.go('/trade_detail/$orderId');
        }
        break;

      case Action.released:
        if (isRecent && !bypassTimestampGate) {
          navProvider.go('/trade_detail/$orderId');
        }
        break;

      case Action.purchaseCompleted:
        if (isRecent && !bypassTimestampGate) {
          navProvider.go('/trade_detail/$orderId');
        }
        break;

      case Action.cooperativeCancelInitiatedByYou:
      case Action.cooperativeCancelNoFiatByYou:
      case Action.cooperativeCancelFiatSentByYou:
        // No additional logic needed beyond notification
        break;

      case Action.cooperativeCancelInitiatedByPeer:
      case Action.cooperativeCancelNoFiatByPeer:
      case Action.cooperativeCancelFiatSentByPeer:
        if (isRecent && !bypassTimestampGate) {
          navProvider.go('/trade_detail/$orderId');
        }
        break;

      case Action.disputeInitiatedByYou:
        final dispute = event.getPayload<Dispute>();
        if (dispute == null) {
          logger.e(
              'disputeInitiatedByYou: Missing Dispute payload for event ${event.id} with action ${event.action}');
          return;
        }

        // Ensure dispute has the orderId for proper association and correct status
        // Also ensure createdAt is set from event timestamp if not already present
        final createdAt = dispute.createdAt ??
            (event.timestamp != null
                ? DateTime.fromMillisecondsSinceEpoch(event.timestamp!)
                : DateTime.now());

        final disputeWithOrderId = dispute.copyWith(
          orderId: orderId,
          status: dispute.status ??
              'initiated', // Ensure status is set for user-initiated disputes
          action: 'dispute-initiated-by-you', // Store the action for UI logic
          createdAt: createdAt, // Ensure timestamp is preserved
        );

        // Save dispute in state for listing
        state = state.copyWith(dispute: disputeWithOrderId);

        // Persist disputeId on session for background notification routing
        final sessionNotifierForDispute = ref.read(sessionNotifierProvider.notifier);
        await sessionNotifierForDispute.updateSession(
          orderId, (s) => s.disputeId = disputeWithOrderId.disputeId,
        );

        // Notification handled by centralized NotificationDataExtractor path
        if (kDebugMode) {
          logger.i(
              'disputeInitiatedByYou: Dispute saved in state, notification handled centrally');
        }

        if (isRecent && !bypassTimestampGate) {
          navProvider.go('/trade_detail/$orderId');
        }

        break;

      case Action.disputeInitiatedByPeer:
        if (kDebugMode) {
          logger.i('disputeInitiatedByPeer: Raw payload: ${event.payload}');
        }
        var dispute = event.getPayload<Dispute>();
        if (kDebugMode) {
          logger.i('disputeInitiatedByPeer: Parsed dispute: $dispute');
        }

        // If payload is not a Dispute object, try to create one from the payload map
        if (dispute == null && event.payload != null) {
          try {
            // Try to create Dispute from payload map (e.g., {dispute: "id"})
            final payloadMap = event.payload as Map<String, dynamic>;
            if (kDebugMode) {
              logger.i('disputeInitiatedByPeer: Payload map: $payloadMap');
            }

            if (payloadMap.containsKey('dispute')) {
              final disputeId = payloadMap['dispute'] as String;

              // Use the event timestamp (from gift-wrapped message) if available,
              // otherwise fall back to DateTime.now().
              final createdAt = event.timestamp != null
                  ? DateTime.fromMillisecondsSinceEpoch(event.timestamp!)
                  : DateTime.now();

              dispute = Dispute(
                disputeId: disputeId,
                orderId: orderId,
                status: 'initiated',
                action: 'dispute-initiated-by-peer',
                createdAt: createdAt,
              );
              logger.i(
                  'disputeInitiatedByPeer: Created dispute from ID: $disputeId with timestamp: $createdAt');
            }
          } catch (e) {
            logger.e(
                'disputeInitiatedByPeer: Failed to create dispute from payload: $e');
          }
        }

        if (dispute == null) {
          logger.e(
              'disputeInitiatedByPeer: Could not create or find Dispute for event ${event.id}');
          return;
        }

        logger.i(
            'disputeInitiatedByPeer: Dispute details - ID: ${dispute.disputeId}, Status: ${dispute.status}, Action: ${dispute.action}, createdAt: ${dispute.createdAt}');

        // Ensure dispute has the orderId for proper association and correct status/action
        // Also ensure createdAt is set from event timestamp if not already present
        final createdAt = dispute.createdAt ??
            (event.timestamp != null
                ? DateTime.fromMillisecondsSinceEpoch(event.timestamp!)
                : DateTime.now());

        final disputeWithOrderId = dispute.copyWith(
          orderId: orderId,
          status: dispute.status ?? 'initiated', // Ensure status is set
          action: 'dispute-initiated-by-peer', // Store the action for UI logic
          createdAt: createdAt, // Ensure timestamp is preserved
        );
        logger.i(
            'disputeInitiatedByPeer: Final dispute - ID: ${disputeWithOrderId.disputeId}, Status: ${disputeWithOrderId.status}, Action: ${disputeWithOrderId.action}, createdAt: ${disputeWithOrderId.createdAt}');

        // Save dispute in state for listing
        state = state.copyWith(dispute: disputeWithOrderId);

        // Persist disputeId on session for background notification routing
        final sessionNotifierForPeerDispute = ref.read(sessionNotifierProvider.notifier);
        await sessionNotifierForPeerDispute.updateSession(
          orderId, (s) => s.disputeId = disputeWithOrderId.disputeId,
        );

        // Notification handled by centralized NotificationDataExtractor path
        if (kDebugMode) {
          logger.i(
              'disputeInitiatedByPeer: Dispute saved in state, notification handled centrally');
        }

        if (isRecent && !bypassTimestampGate) {
          navProvider.go('/trade_detail/$orderId');
        }

        break;

      case Action.adminTookDispute:
        // Compute admin shared key and persist on session
        String? adminPubkey;
        if (event.payload is Peer) {
          final peerPayload = event.getPayload<Peer>();
          if (peerPayload != null && peerPayload.publicKey.isNotEmpty) {
            adminPubkey = peerPayload.publicKey;
          }
        }
        // Fallback: check dispute in state
        adminPubkey ??= state.dispute?.adminPubkey;

        if (adminPubkey != null && adminPubkey.isNotEmpty) {
          try {
            final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
            await sessionNotifier.updateSession(
                orderId, (s) => s.setAdminPeer(adminPubkey!));
            // Re-fetch session to reflect the updated adminSharedKey
            final refreshed = sessionNotifier.getSessionByOrderId(orderId);
            if (refreshed != null) {
              session = refreshed;
            }
            logger.i(
                'Admin shared key computed and persisted for order $orderId');
          } catch (e) {
            logger.e(
                'adminTookDispute: Failed to set admin peer for order $orderId: $e');
          }
        } else {
          logger.w(
              'adminTookDispute: Could not extract admin pubkey for order $orderId');
        }

        if (isRecent && !bypassTimestampGate) {
          navProvider.go('/trade_detail/$orderId');
        }
        break;

      case Action.adminSettled:
        if (isRecent && !bypassTimestampGate) {
          navProvider.go('/trade_detail/$orderId');
        }
        break;

      case Action.cantDo:
        final cantDo = event.getPayload<CantDo>();

        // Cleanup for specific errors
        if (cantDo?.cantDoReason == CantDoReason.outOfRangeSatsAmount) {
          if (event.requestId != null) {
            ref
                .read(sessionNotifierProvider.notifier)
                .cleanupRequestSession(event.requestId!);
          }
        }

        // Cleanup for order taking failures - delete session by orderId
        if (cantDo?.cantDoReason == CantDoReason.pendingOrderExists) {
          ref.read(sessionNotifierProvider.notifier).deleteSession(orderId);
        }
        break;

      case Action.rate:
        // No additional logic needed beyond notification
        break;

      case Action.rateReceived:
        break;

      // Default
      default:
        break;
    }
  }

  bool _isUserCreator() {
    if (session.role == null || state.order == null) {
      return false;
    }
    return session.role == Role.buyer
        ? state.order!.kind == OrderType.buy
        : state.order!.kind == OrderType.sell;
  }

  /// Starts a 10-second timer to cleanup orphan sessions if no response from Mostro
  static void startSessionTimeoutCleanup(String orderId, Ref ref) {
    // Cancel existing timer if any
    _sessionTimeouts[orderId]?.cancel();

    _sessionTimeouts[orderId] = Timer(const Duration(seconds: 10), () {
      try {
        ref.read(sessionNotifierProvider.notifier).deleteSession(orderId);
        logger.i('Session cleaned up after 10s timeout: $orderId');

        // Show timeout message to user and navigate to order book
        _showTimeoutNotificationAndNavigate(ref);
      } catch (e) {
        logger.e('Failed to cleanup session: $orderId', error: e);
      }
      _sessionTimeouts.remove(orderId);
    });

    logger.i('Started 10s timeout timer for order: $orderId');
  }

  /// Shows timeout notification and navigates to order book
  static void _showTimeoutNotificationAndNavigate(Ref ref) {
    try {
      // Show snackbar with localized timeout message
      final notificationNotifier =
          ref.read(notificationActionsProvider.notifier);
      notificationNotifier.showCustomMessage('sessionTimeoutMessage');

      // Navigate to main order book screen (home)
      final navProvider = ref.read(navigationProvider.notifier);
      navProvider.go('/');
    } catch (e) {
      logger.e('Failed to show timeout notification or navigate', error: e);
    }
  }

  /// Starts a 10-second timer to cleanup orphan sessions for create orders (by requestId)
  static void startSessionTimeoutCleanupForRequestId(int requestId, Ref ref) {
    final key = 'request:$requestId';
    // Cancel existing timer if any
    _sessionTimeouts[key]?.cancel();

    _sessionTimeouts[key] = Timer(const Duration(seconds: 10), () {
      try {
        ref
            .read(sessionNotifierProvider.notifier)
            .deleteSessionByRequestId(requestId);
        logger.i(
            'Session cleaned up after 10s timeout for requestId: $requestId');

        // Show timeout message to user and navigate to order book
        _showTimeoutNotificationAndNavigate(ref);
      } catch (e) {
        logger.e('Failed to cleanup session for requestId: $requestId',
            error: e);
      }
      _sessionTimeouts.remove(key);
    });

    logger.i('Started 10s timeout timer for requestId: $requestId');
  }

  /// Cancels the timeout timer for a specific orderId
  static void cancelSessionTimeoutCleanup(String orderId) {
    final timer = _sessionTimeouts[orderId];
    if (timer != null) {
      timer.cancel();
      _sessionTimeouts.remove(orderId);
      logger.i(
          'Cancelled 10s timeout timer for order: $orderId - Mostro responded');
    }
  }

  /// Cancels the timeout timer for a specific requestId
  static void cancelSessionTimeoutCleanupForRequestId(int requestId) {
    final key = 'request:$requestId';
    final timer = _sessionTimeouts[key];
    if (timer != null) {
      timer.cancel();
      _sessionTimeouts.remove(key);
      logger.i(
          'Cancelled 10s timeout timer for requestId: $requestId - Mostro responded');
    }
  }

  /// Test-only: whether a create-order timeout timer is currently armed for
  /// [requestId]. Lets tests assert the maker-bond flow tears the timer down.
  @visibleForTesting
  static bool hasRequestTimeout(int requestId) =>
      _sessionTimeouts.containsKey('request:$requestId');

  /// Whether a bond was requested for this order (a pay-bond-invoice was sent).
  Future<bool> _orderHadBond(String orderId) async {
    try {
      final messages = await ref
          .read(mostroStorageProvider)
          .getAllMessagesForOrderId(orderId);
      return messages.any((m) => m.action == Action.payBondInvoice);
    } catch (e) {
      logger.e('Failed to check bond for order $orderId', error: e);
      return false;
    }
  }

  /// Defers deletion of a canceled bonded order's session for 60s so a trailing
  /// bond-slashed notice can still be received and surfaced. Cancelled early by
  /// the bond-slashed handler when the notice arrives.
  static void _startBondCancelDeletion(String orderId, Ref ref) {
    _bondCancelDeletionTimers[orderId]?.cancel();
    _bondCancelDeletionTimers[orderId] = Timer(_bondCancelGraceWindow, () {
      _bondCancelDeletionTimers.remove(orderId);
      try {
        ref.read(sessionNotifierProvider.notifier).deleteSession(orderId);
        logger.i('Session deleted after bond-cancel grace window: $orderId');
      } catch (e) {
        logger.e('Failed to delete session after grace window: $orderId',
            error: e);
      }
    });
  }

  static const Duration _bondCancelGraceWindow = Duration(seconds: 60);

  /// Clears any pending bond-cancel deletion state for an order. Called when a
  /// fresh session is taken, so a stale grace timer (or user-cancel flag) from
  /// a previous cycle on the same orderId can't delete the new session.
  @protected
  static void clearBondCancelDeletion(String orderId) {
    _bondCancelDeletionTimers.remove(orderId)?.cancel();
    _userInitiatedCancels.remove(orderId);
  }

  /// Restart-resilient cleanup for a canceled bonded order. The deferred
  /// deletion above relies on an in-memory timer that is lost if the app
  /// closes within the grace window, which would orphan the session forever
  /// (the canceled message is then too old to pass the timestamp gate and
  /// re-arm the timer). Called after state is rebuilt from storage on startup:
  /// if the grace window already elapsed (or the bond-slashed notice already
  /// arrived), delete now; otherwise re-arm the timer for the remainder so a
  /// trailing bond-slashed can still be received.
  @protected
  Future<void> reconcileCanceledBondedSession() async {
    // A live cancel arms the timer itself; don't interfere with it.
    if (_bondCancelDeletionTimers.containsKey(orderId)) return;

    final sessionExists = ref.read(sessionProvider(orderId)) != null;
    final hadBond = sessionExists && await _orderHadBond(orderId);

    var bondSlashedReceived = false;
    var canceledTs = 0;
    if (hadBond) {
      final messages = await ref
          .read(mostroStorageProvider)
          .getAllMessagesForOrderId(orderId);
      bondSlashedReceived = messages.any((m) => m.action == Action.bondSlashed);
      canceledTs = latestCanceledTimestamp(messages);
    }

    final decision = reconcileBondCancelAction(
      sessionExists: sessionExists,
      hadBond: hadBond,
      bondSlashedReceived: bondSlashedReceived,
      latestCanceledTimestamp: canceledTs,
      nowMs: DateTime.now().millisecondsSinceEpoch,
      graceWindowMs: _bondCancelGraceWindow.inMilliseconds,
    );

    switch (decision) {
      case BondCancelReconcileAction.none:
        return;
      case BondCancelReconcileAction.deleteNow:
        await ref.read(sessionNotifierProvider.notifier).deleteSession(orderId);
        logger.i(
            'Reconcile: deleted orphaned canceled bonded session $orderId');
      case BondCancelReconcileAction.rearm:
        _startBondCancelDeletion(orderId, ref);
        logger.i('Reconcile: re-armed bond-cancel grace timer for $orderId');
    }
  }

  /// Handles add-invoice action with automatic Lightning address sending if available
  Future<void> _handleAddInvoiceWithAutoLightningAddress(
      MostroMessage event) async {
    // Check if this add-invoice comes after a payment-failed
    // If status is paymentFailed, don't auto-send Lightning address - use manual input
    if (state.status == Status.paymentFailed) {
      logger.i(
          'add-invoice after payment-failed detected - using manual input instead of auto Lightning address');
      _navigateToManualInvoiceInput();
      return;
    }

    final settings = ref.read(settingsProvider);
    final lightningAddress = settings.defaultLightningAddress?.trim();

    if (lightningAddress != null &&
        lightningAddress.isNotEmpty &&
        _isValidLightningAddress(lightningAddress)) {
      logger
          .i('Lightning address available, navigating to confirmation screen');
      // Navigate to the invoice screen with the Lightning address for user confirmation
      final navProvider = ref.read(navigationProvider.notifier);
      navProvider.go(
          '/add_invoice/$orderId?lnAddress=${Uri.encodeComponent(lightningAddress)}');
    } else {
      // No Lightning address or invalid format - use manual input
      _navigateToManualInvoiceInput();
    }
  }

  /// Validates Lightning address format (user@domain.tld)
  bool _isValidLightningAddress(String address) {
    // Lightning address format: user@domain.tld
    // More robust validation with character constraints
    final lnAddressRegex =
        RegExp(r'^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return lnAddressRegex.hasMatch(address);
  }

  /// Navigate to manual invoice input screen
  void _navigateToManualInvoiceInput() {
    final navProvider = ref.read(navigationProvider.notifier);
    navProvider.go('/add_invoice/$orderId');
  }

  @override
  void dispose() {
    subscription?.close();
    // Cancel timer for this specific orderId if it exists
    _sessionTimeouts[orderId]?.cancel();
    _sessionTimeouts.remove(orderId);
    super.dispose();
  }
}
