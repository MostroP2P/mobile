import 'dart:async';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';
import 'package:mostro_mobile/shared/providers.dart';
import 'package:mostro_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:mostro_mobile/features/order/notfiers/abstract_mostro_notifier.dart';
import 'package:mostro_mobile/services/mostro_service.dart';

class OrderNotifier extends AbstractMostroNotifier {
  late final MostroService mostroService;
  ProviderSubscription<AsyncValue<List<NostrEvent>>>? _publicEventsSubscription;
  bool _isProcessingTimeout = false;
  OrderNotifier(super.orderId, super.ref) {
    mostroService = ref.read(mostroServiceProvider);
    sync();
    subscribe();
    _subscribeToPublicEvents();
  }

  @override
  void handleEvent(MostroMessage event) {
    logger.i('OrderNotifier received event: ${event.action} for order $orderId');
    
    // First handle the event normally
    super.handleEvent(event);
    
    // Skip timeout detection if order is being canceled
    if (event.action == Action.canceled) {
      logger.i('Skipping timeout detection for canceled order $orderId');
      return;
    }
    
    // Then check for timeout if we're in waiting states
    // Only check if we have a valid session (this is a taker scenario)
    final currentSession = ref.read(sessionProvider(orderId));
    if (mounted && currentSession != null && (state.status == Status.waitingBuyerInvoice || state.status == Status.waitingPayment)) {
      // Schedule the async timeout check without blocking
      Future.microtask(() async {
        final shouldCleanup = await _checkTimeoutAndCleanup(state, event);
        if (shouldCleanup && mounted) {
          // Session was cleaned up, invalidate this provider
          ref.invalidateSelf();
        }
      });
    }
  }

  Future<void> sync() async {
    if (_isProcessingTimeout) return;
    
    try {
      _isProcessingTimeout = true;
      
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
      MostroMessage? latestGiftWrap;
      
      for (final message in messages) {
        if (message.action != Action.cantDo) {
          currentState = currentState.updateWith(message);
          latestGiftWrap = message; // Keep track of latest gift wrap
        }
      }
      
      // Check if we should cleanup session due to timeout
      // Only check if we have a valid session (this is a taker scenario)
      final currentSession = ref.read(sessionProvider(orderId));
      if (currentSession != null) {
        final shouldCleanup = await _checkTimeoutAndCleanup(currentState, latestGiftWrap);
        if (shouldCleanup) {
          // Session was cleaned up, this provider should be invalidated
          ref.invalidateSelf();
          return;
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
    } finally {
      _isProcessingTimeout = false;
    }
  }

  Future<void> takeSellOrder(
      String orderId, int? amount, String? lnAddress) async {
    final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
    session = await sessionNotifier.newSession(
      orderId: orderId,
      role: Role.buyer,
    );
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

  /// Check if session should be cleaned up due to timeout
  /// Returns true if session was cleaned up, false otherwise
  Future<bool> _checkTimeoutAndCleanup(OrderState currentState, MostroMessage? latestGiftWrap) async {
    // Only check for timeout/cancellation in waiting states
    if (currentState.status != Status.waitingBuyerInvoice && 
        currentState.status != Status.waitingPayment) {
      return false;
    }

    if (latestGiftWrap == null) {
      return false;
    }

    try {
      // Get the public event for this order from 38383 events
      final publicEventAsync = ref.read(eventProvider(orderId));
      if (publicEventAsync == null) {
        // No public event found, no cleanup needed
        return false;
      }

      final publicEvent = publicEventAsync;
      
      // Compare timestamps: public event vs latest gift wrap
      final publicTimestamp = publicEvent.createdAt;
      final giftWrapTimestamp = DateTime.fromMillisecondsSinceEpoch(latestGiftWrap.timestamp ?? 0);
      
      if (publicTimestamp != null && publicTimestamp.isAfter(giftWrapTimestamp)) {
        // Check if order was canceled
        if (publicEvent.status == Status.canceled) {
          logger.i('CANCELLATION detected for order $orderId via public event');
          
          // CANCELED: Always delete session for both maker and taker
          final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
          await sessionNotifier.deleteSession(orderId);
          logger.i('Session deleted for canceled order $orderId');
          
          // Show cancellation notification
          final notifProvider = ref.read(notificationsProvider.notifier);
          notifProvider.showCustomMessage('orderCanceled');
          
          // Navigate to order book
          final navProvider = ref.read(navigationProvider.notifier);
          navProvider.go('/order_book');
          
          return true; // Session was cleaned up
        }
        
        // Check if order timed out (returned to pending)
        if (publicEvent.status == Status.pending) {
          // Timeout detected: Public event is newer and shows pending
          logger.i('Timeout detected for order $orderId: Public event ($publicTimestamp) is newer than gift wrap ($giftWrapTimestamp)');
        
          // Determine if this is a maker (created by user) or taker (taken by user)
          final currentSession = ref.read(sessionProvider(orderId));
        if (currentSession == null) {
          return false;
        }
        
        final isCreatedByUser = _isCreatedByUser(currentSession, publicEvent);
        
        if (isCreatedByUser) {
          // MAKER SCENARIO: Keep session but update state to pending
          logger.i('Order created by user - updating state to pending while keeping session');
          
          // Show notification: counterpart didn't respond, order will be republished
          _showTimeoutNotification(isCreatedByUser: true);
          
          // CRITICAL: Persist the timeout reversal to maintain pending status after app restart
          try {
            final storage = ref.read(mostroStorageProvider);
            final timeoutMessage = MostroMessage.createTimeoutReversal(
              orderId: orderId,
              timestamp: publicTimestamp.millisecondsSinceEpoch,
              originalStatus: currentState.status,
              publicEvent: publicEvent,
            );
            
            // Use a unique key that includes timestamp to avoid conflicts
            final messageKey = '${orderId}_timeout_${publicTimestamp.millisecondsSinceEpoch}';
            await storage.addMessage(messageKey, timeoutMessage)
                .timeout(Config.messageStorageTimeout, onTimeout: () {
                  logger.w('Timeout persisting timeout reversal message for order $orderId - continuing anyway');
                });
            
            logger.i('Timeout reversal message persisted for order $orderId');
          } catch (e, stack) {
            logger.e('Failed to persist timeout reversal message for order $orderId', 
                     error: e, stackTrace: stack);
            // Continue execution even if persistence fails
          }
          
          // Update state to pending without removing session
          state = state.copyWith(
            status: Status.pending,
            action: Action.timeoutReversal,
          );
          
          // Return false to indicate no cleanup (session preserved)
          return false;
          
        } else {
          // TAKER SCENARIO: Remove session completely
          logger.i('Order taken by user - cleaning up session as order will be removed from My Trades');
          
          // Show notification: user didn't respond
          _showTimeoutNotification(isCreatedByUser: false);
          
          final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
          await sessionNotifier.deleteSession(orderId);
          
          // Return true to indicate session was cleaned up
          return true;
        }
        }
      }

      // No timeout/cancellation detected, no cleanup needed
      return false;
      
    } catch (e, stack) {
      logger.e(
        'Error checking timeout for order $orderId',
        error: e,
        stackTrace: stack,
      );
      // On error, no cleanup
      return false;
    }
  }

  /// Determine if the order was created by the user (maker) or taken by user (taker)
  bool _isCreatedByUser(Session session, NostrEvent publicEvent) {
    final userRole = session.role;
    final orderType = publicEvent.orderType;
    
    // Logic from TradesListItem: user is creator if role matches order type
    if (userRole == Role.buyer && orderType == OrderType.buy) {
      return true; // User created a buy order as buyer
    }
    
    if (userRole == Role.seller && orderType == OrderType.sell) {
      return true; // User created a sell order as seller
    }
    
    return false; // User took someone else's order (taker)
  }

  /// Subscribe to public events (38383) to detect timeout in real-time
  void _subscribeToPublicEvents() {
    _publicEventsSubscription = ref.listen(
      orderEventsProvider,
      (_, next) async {
        // Prevent multiple timeout processing from running concurrently
        if (_isProcessingTimeout) {
          logger.d('Timeout processing already in progress for order $orderId');
          return;
        }
        
        try {
          _isProcessingTimeout = true;
          
          // Verify current state (could have changed)
          final currentSession = ref.read(sessionProvider(orderId));
          if (!mounted || currentSession == null) {
            return;
          }
          
          // Re-verify state after setting flag
          if (state.status != Status.waitingBuyerInvoice && 
              state.status != Status.waitingPayment) {
            return;
          }
          
          final storage = ref.read(mostroStorageProvider);
          final messages = await storage.getAllMessagesForOrderId(orderId)
              .timeout(Config.timeoutDetectionTimeout, onTimeout: () {
                logger.w('Timeout getting messages for timeout detection in order $orderId - skipping cleanup');
                return <MostroMessage>[];
              });
          
          if (messages.isNotEmpty) {
            messages.sort((a, b) => (a.timestamp ?? 0).compareTo(b.timestamp ?? 0));
            final latestGiftWrap = messages.last;
            
            // Verify state one more time before cleanup
            if (mounted && (state.status == Status.waitingBuyerInvoice || 
                state.status == Status.waitingPayment)) {
              final shouldCleanup = await _checkTimeoutAndCleanup(state, latestGiftWrap)
                  .timeout(Config.timeoutDetectionTimeout, onTimeout: () {
                    logger.w('Timeout in cleanup detection for order $orderId - assuming no cleanup needed');
                    return false;
                  });
              if (shouldCleanup) {
                logger.i('Real-time timeout detected - cleaning up session for order $orderId');
                ref.invalidateSelf();
              }
            }
          }
        } finally {
          _isProcessingTimeout = false;
        }
      },
    );
  }

  /// Show timeout notification message
  void _showTimeoutNotification({required bool isCreatedByUser}) {
    try {
      final notificationNotifier = ref.read(notificationsProvider.notifier);
      
      // Show appropriate message based on user role
      if (isCreatedByUser) {
        // User is maker - counterpart didn't respond
        // Use key for translation lookup in the UI
        notificationNotifier.showTemporary(Action.timeoutReversal, values: {'type': 'maker'});
      } else {
        // User is taker - user didn't respond
        // Use key for translation lookup in the UI
        notificationNotifier.showTemporary(Action.timeoutReversal, values: {'type': 'taker'});
      }
    } catch (e, stack) {
      logger.e('Error showing timeout notification', error: e, stackTrace: stack);
    }
  }

  @override
  void dispose() {
    _publicEventsSubscription?.close();
    super.dispose();
  }
}
