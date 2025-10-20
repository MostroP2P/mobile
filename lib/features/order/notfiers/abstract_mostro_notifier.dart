import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';
import 'package:mostro_mobile/shared/providers.dart';
import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:mostro_mobile/features/notifications/utils/notification_data_extractor.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:logger/logger.dart';

class AbstractMostroNotifier extends StateNotifier<OrderState> {
  final String orderId;
  final Ref ref;
  final logger = Logger();

  late Session session;

  ProviderSubscription<AsyncValue<MostroMessage?>>? subscription;
  final Set<String> _processedEventIds = <String>{};
  
  // Timer storage for orphan session cleanup
  static final Map<String, Timer> _sessionTimeouts = {};

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
            if (kDebugMode) {
              logger.i('Received message: ${msg?.toJson()}');
            } else {
              logger.i('Received message with action: ${msg?.action}');
            }
            if (msg != null) {
              // Cancel timer on ANY response from Mostro for this order
              cancelSessionTimeoutCleanup(orderId);
              
              if (mounted) {
                state = state.updateWith(msg);
              }
              if (msg.timestamp != null &&
                  msg.timestamp! >
                      DateTime.now()
                          .subtract(const Duration(seconds: 60))
                          .millisecondsSinceEpoch) {
                logger.i('Message timestamp check passed, calling handleEvent for ${msg.action}');
                unawaited(handleEvent(msg));
              } else {
                logger.w('Message timestamp check failed for ${msg.action}. Timestamp: ${msg.timestamp}, Current: ${DateTime.now().millisecondsSinceEpoch}, Threshold: ${DateTime.now().subtract(const Duration(seconds: 60)).millisecondsSinceEpoch}');
                
                // Handle dispute actions even if timestamp is old, since they're critical for UI state
                // but bypass navigation/notification side effects
                if (msg.action == Action.disputeInitiatedByPeer || msg.action == Action.disputeInitiatedByYou) {
                  logger.i('Processing dispute action ${msg.action} despite old timestamp (state update only)');
                  unawaited(handleEvent(msg, bypassTimestampGate: true));
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

  void sendNotification(Action action, {Map<String, dynamic>? values, bool isTemporary = false, String? eventId}) {
    final notifProvider = ref.read(notificationActionsProvider.notifier);
    
    if (isTemporary) {
      notifProvider.showTemporary(action, values: values ?? {});
    } else {
      notifProvider.notify(action, values: values ?? {}, orderId: orderId, eventId: eventId);
    }
  }

  Future<void> handleEvent(MostroMessage event, {bool bypassTimestampGate = false}) async {
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
    final notificationData = await NotificationDataExtractor.extractFromMostroMessage(event, ref, session: session);
    
    // Only notify for recent events; old disputes still update state below
    if (notificationData != null && (isRecent || !bypassTimestampGate)) {
      sendNotification(
        notificationData.action,
        values: notificationData.values,
        isTemporary: notificationData.isTemporary,
        eventId: notificationData.eventId,
      );
    } else if (notificationData != null && bypassTimestampGate) {
      logger.i('Skipping notification for old event: ${event.action} (timestamp: ${event.timestamp})');
    }

    /// Handle incoming events and update state accordingly
    logger.i('handleEvent: Processing action ${event.action} for order $orderId (bypassTimestampGate: $bypassTimestampGate)');
    switch (event.action) {
      case Action.newOrder:
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

      case Action.addInvoice:
        final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
        sessionNotifier.saveSession(session);
        await _handleAddInvoiceWithAutoLightningAddress(event);
        break;

      case Action.holdInvoicePaymentAccepted:
        final order = event.getPayload<Order>();
        if (order == null) return;

        // Update session and state with correct peer based on session role
        final sessionProvider = ref.read(sessionNotifierProvider.notifier);
        
        // Re-fetch session to ensure it's initialized
        final fetchedSession = sessionProvider.getSessionByOrderId(orderId);
        if (fetchedSession == null) {
          logger.e('Session not found for order $orderId in holdInvoicePaymentAccepted');
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
        break;

      case Action.released:
        // No additional logic needed beyond notification
        break;

      case Action.purchaseCompleted:
        // No additional logic needed beyond notification
        break;

      case Action.canceled:
        // Cleanup
        ref.read(mostroStorageProvider).deleteAllMessagesByOrderId(orderId);
        ref.read(sessionNotifierProvider.notifier).deleteSession(orderId);
        
        // Navigate to main order book screen and invalidate
        navProvider.go('/');
        ref.invalidateSelf();
        break;

      case Action.cooperativeCancelInitiatedByYou:
        // No additional logic needed beyond notification
        break;

      case Action.cooperativeCancelInitiatedByPeer:
        // No additional logic needed beyond notification
        break;

      case Action.disputeInitiatedByYou:
        final dispute = event.getPayload<Dispute>();
        if (dispute == null) {
          logger.e('disputeInitiatedByYou: Missing Dispute payload for event ${event.id} with action ${event.action}');
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
          status: dispute.status ?? 'initiated', // Ensure status is set for user-initiated disputes
          action: 'dispute-initiated-by-you', // Store the action for UI logic
          createdAt: createdAt, // Ensure timestamp is preserved
        );

        // Save dispute in state for listing
        state = state.copyWith(dispute: disputeWithOrderId);

        // Notification handled by centralized NotificationDataExtractor path
        if (kDebugMode) {
          logger.i('disputeInitiatedByYou: Dispute saved in state, notification handled centrally');
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
              logger.i('disputeInitiatedByPeer: Created dispute from ID: $disputeId with timestamp: $createdAt');
            }
          } catch (e) {
            logger.e('disputeInitiatedByPeer: Failed to create dispute from payload: $e');
          }
        }
        
        if (dispute == null) {
          logger.e('disputeInitiatedByPeer: Could not create or find Dispute for event ${event.id}');
          return;
        }


        logger.i('disputeInitiatedByPeer: Dispute details - ID: ${dispute.disputeId}, Status: ${dispute.status}, Action: ${dispute.action}, createdAt: ${dispute.createdAt}');
        
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
        logger.i('disputeInitiatedByPeer: Final dispute - ID: ${disputeWithOrderId.disputeId}, Status: ${disputeWithOrderId.status}, Action: ${disputeWithOrderId.action}, createdAt: ${disputeWithOrderId.createdAt}');


        // Save dispute in state for listing
        state = state.copyWith(dispute: disputeWithOrderId);

        // Notification handled by centralized NotificationDataExtractor path
        if (kDebugMode) {
          logger.i('disputeInitiatedByPeer: Dispute saved in state, notification handled centrally');
        }

        break;

      case Action.adminSettled:
        // No additional logic needed beyond notification
        break;

      case Action.cantDo:
        final cantDo = event.getPayload<CantDo>();
        
        // Cleanup for specific errors
        if (cantDo?.cantDoReason == CantDoReason.outOfRangeSatsAmount) {
          if (event.requestId != null) {
            ref.read(sessionNotifierProvider.notifier).cleanupRequestSession(event.requestId!);
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

      case Action.timeoutReversal:
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
        Logger().i('Session cleaned up after 10s timeout: $orderId');
        
        // Show timeout message to user and navigate to order book
        _showTimeoutNotificationAndNavigate(ref);
      } catch (e) {
        Logger().e('Failed to cleanup session: $orderId', error: e);
      }
      _sessionTimeouts.remove(orderId);
    });
    
    Logger().i('Started 10s timeout timer for order: $orderId');
  }
  
  /// Shows timeout notification and navigates to order book
  static void _showTimeoutNotificationAndNavigate(Ref ref) {
    try {
      // Show snackbar with localized timeout message
      final notificationNotifier = ref.read(notificationActionsProvider.notifier);
      notificationNotifier.showCustomMessage('sessionTimeoutMessage');
      
      // Navigate to main order book screen (home)
      final navProvider = ref.read(navigationProvider.notifier);
      navProvider.go('/');
    } catch (e) {
      Logger().e('Failed to show timeout notification or navigate', error: e);
    }
  }
  
  /// Starts a 10-second timer to cleanup orphan sessions for create orders (by requestId)
  static void startSessionTimeoutCleanupForRequestId(int requestId, Ref ref) {
    final key = 'request:$requestId';
    // Cancel existing timer if any
    _sessionTimeouts[key]?.cancel();
    
    _sessionTimeouts[key] = Timer(const Duration(seconds: 10), () {
      try {
        ref.read(sessionNotifierProvider.notifier).deleteSessionByRequestId(requestId);
        Logger().i('Session cleaned up after 10s timeout for requestId: $requestId');
        
        // Show timeout message to user and navigate to order book
        _showTimeoutNotificationAndNavigate(ref);
      } catch (e) {
        Logger().e('Failed to cleanup session for requestId: $requestId', error: e);
      }
      _sessionTimeouts.remove(key);
    });
    
    Logger().i('Started 10s timeout timer for requestId: $requestId');
  }
  
  /// Cancels the timeout timer for a specific orderId
  static void cancelSessionTimeoutCleanup(String orderId) {
    final timer = _sessionTimeouts[orderId];
    if (timer != null) {
      timer.cancel();
      _sessionTimeouts.remove(orderId);
      Logger().i('Cancelled 10s timeout timer for order: $orderId - Mostro responded');
    }
  }
  
  /// Cancels the timeout timer for a specific requestId
  static void cancelSessionTimeoutCleanupForRequestId(int requestId) {
    final key = 'request:$requestId';
    final timer = _sessionTimeouts[key];
    if (timer != null) {
      timer.cancel();
      _sessionTimeouts.remove(key);
      Logger().i('Cancelled 10s timeout timer for requestId: $requestId - Mostro responded');
    }
  }

  /// Handles add-invoice action with automatic Lightning address sending if available
  Future<void> _handleAddInvoiceWithAutoLightningAddress(MostroMessage event) async {
    // Check if this add-invoice comes after a payment-failed
    // If status is paymentFailed, don't auto-send Lightning address - use manual input
    if (state.status == Status.paymentFailed) {
      logger.i('add-invoice after payment-failed detected - using manual input instead of auto Lightning address');
      _navigateToManualInvoiceInput();
      return;
    }
    
    final settings = ref.read(settingsProvider);
    final lightningAddress = settings.defaultLightningAddress?.trim();
    
    if (lightningAddress != null && lightningAddress.isNotEmpty && _isValidLightningAddress(lightningAddress)) {
      logger.i('Auto-sending Lightning address for add-invoice: $lightningAddress');
      
      try {
        // For Lightning addresses, amount should always be null
        // because the Lightning address handles the amount automatically
        const int? amount = null;
        logger.i('Sending Lightning address with amount: null (Lightning address handles amount)');
        
        // Send Lightning address automatically
        final mostroService = ref.read(mostroServiceProvider);
        await mostroService.sendInvoice(orderId, lightningAddress, amount);
        
        // Show feedback to user
        final notificationNotifier = ref.read(notificationActionsProvider.notifier);
        notificationNotifier.showCustomMessage('lightningAddressUsed');
        
        logger.i('Lightning address sent successfully for order: $orderId');
      } catch (e) {
        logger.e('Failed to send Lightning address automatically: $e');
        // Fallback to manual input if auto-send fails
        _navigateToManualInvoiceInput();
      }
    } else {
      // No Lightning address or invalid format - use manual input
      _navigateToManualInvoiceInput();
    }
  }

  /// Validates Lightning address format (basic email-like validation)
  bool _isValidLightningAddress(String address) {
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    return emailRegex.hasMatch(address);
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
