import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';
import 'package:mostro_mobile/shared/providers.dart';
import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:mostro_mobile/features/notifications/utils/notification_data_extractor.dart';
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
            logger.i('Received message: ${msg?.toJson()}');
            if (msg != null) {
              if (mounted) {
                state = state.updateWith(msg);
              }
              if (msg.timestamp != null &&
                  msg.timestamp! >
                      DateTime.now()
                          .subtract(const Duration(seconds: 60))
                          .millisecondsSinceEpoch) {
                unawaited(handleEvent(msg));
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

  Future<void> handleEvent(MostroMessage event) async {
    // Skip if we've already processed this exact event
    final eventKey = '${event.id}_${event.action}_${event.timestamp}';
    if (_processedEventIds.contains(eventKey)) {
      logger.d('Skipping duplicate event: $eventKey');
      return;
    }
    _processedEventIds.add(eventKey);
    
    // Cancel timer on ANY response from Mostro for this order
    _cancelSessionTimeoutCleanup(orderId);
    
    final navProvider = ref.read(navigationProvider.notifier);

    // Extract notification data using the centralized extractor
    final notificationData = await NotificationDataExtractor.extractFromMostroMessage(event, ref, session: session);
    
    // Send notification if data was extracted
    if (notificationData != null) {
      sendNotification(
        notificationData.action,
        values: notificationData.values,
        isTemporary: notificationData.isTemporary,
        eventId: notificationData.eventId,
      );
    }

    // Handle navigation and business logic for each action
    switch (event.action) {
      case Action.newOrder:
        break;
        
      case Action.buyerTookOrder:
        final order = event.getPayload<Order>();
        if (order == null) {
          logger.e('Buyer took order, but order is null');
          break;
        }

        // Update session and state
        final sessionProvider = ref.read(sessionNotifierProvider.notifier);
        final peer = order.buyerTradePubkey != null
            ? Peer(publicKey: order.buyerTradePubkey!)
            : null;
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
        navProvider.go('/add_invoice/$orderId');
        break;

      case Action.holdInvoicePaymentAccepted:
        final order = event.getPayload<Order>();
        if (order == null) return;

        // Update session and state
        final sessionProvider = ref.read(sessionNotifierProvider.notifier);
        final peer = order.sellerTradePubkey != null
            ? Peer(publicKey: order.sellerTradePubkey!)
            : null;
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
        break;

      case Action.disputeInitiatedByPeer:
        final dispute = event.getPayload<Dispute>();
        if (dispute == null) {
          logger.e('disputeInitiatedByPeer: Missing Dispute payload for event ${event.id} with action ${event.action}');
          return;
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
  
  /// Cancels the timeout timer for a specific orderId
  static void _cancelSessionTimeoutCleanup(String orderId) {
    final timer = _sessionTimeouts[orderId];
    if (timer != null) {
      timer.cancel();
      _sessionTimeouts.remove(orderId);
      Logger().i('Cancelled 10s timeout timer for order: $orderId - Mostro responded');
    }
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
