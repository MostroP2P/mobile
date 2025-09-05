import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';
import 'package:mostro_mobile/shared/providers.dart';
import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/features/mostro/mostro_instance.dart';
import 'package:mostro_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:mostro_mobile/shared/providers/legible_handle_provider.dart';
import 'package:logger/logger.dart';

class AbstractMostroNotifier extends StateNotifier<OrderState> {
  final String orderId;
  final Ref ref;
  final logger = Logger();

  late Session session;

  ProviderSubscription<AsyncValue<MostroMessage?>>? subscription;

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
                handleEvent(msg);
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

  void handleEvent(MostroMessage event) {
    final navProvider = ref.read(navigationProvider.notifier);
    final mostroInstance = ref.read(orderRepositoryProvider).mostroInstance;

    switch (event.action) {
      case Action.newOrder:
        break;
      case Action.buyerTookOrder:
        final order = event.getPayload<Order>();
        if (order == null) {
          logger.e('Buyer took order, but order is null');
          break;
        }

        // Notification
        final buyerNym = order.buyerTradePubkey != null 
            ? ref.read(nickNameProvider(order.buyerTradePubkey!)) 
            : 'Unknown';
        sendNotification(event.action, values: {
          'buyer_npub': buyerNym,
        }, eventId: event.id);

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
        sendNotification(event.action, eventId: event.id);
        break;

      case Action.addInvoice:
        final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
        sessionNotifier.saveSession(session);

        // Check if payment failure recovery
        final order = event.getPayload<Order>();
        final isAfterPaymentFailure = order?.status == Status.settledHoldInvoice;
        
        // Notification
        if (isAfterPaymentFailure) {
          final now = DateTime.now();
          sendNotification(event.action, values: {
            'fiat_amount': order?.fiatAmount,
            'fiat_code': order?.fiatCode,
            'failed_at': now.millisecondsSinceEpoch,
          }, eventId: event.id);
        } else {
          sendNotification(event.action, eventId: event.id);
        }
        
        navProvider.go('/add_invoice/$orderId');
        break;

      case Action.holdInvoicePaymentAccepted:
        final order = event.getPayload<Order>();
        if (order == null) return;

        // Notification
        final notificationValues = <String, dynamic>{
          'fiat_code': order.fiatCode,
          'fiat_amount': order.fiatAmount,
          'payment_method': order.paymentMethod,
        };
        
        if (order.sellerTradePubkey != null) {
          final sellerNym = ref.read(nickNameProvider(order.sellerTradePubkey!));
          notificationValues['seller_npub'] = sellerNym;
        }
        
        sendNotification(event.action, values: notificationValues, eventId: event.id);

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
        // Notification
        final buyerNym = state.order?.buyerTradePubkey != null 
            ? ref.read(nickNameProvider(state.order!.buyerTradePubkey!)) 
            : 'Unknown';
        sendNotification(event.action, values: {
          'buyer_npub': buyerNym,
        }, eventId: event.id);

        navProvider.go('/trade_detail/$orderId');
        break;

      case Action.paymentFailed:
        final paymentFailed = event.getPayload<PaymentFailed>();
        sendNotification(event.action, values: {
          'payment_attempts': paymentFailed?.paymentAttempts,
          'payment_retries_interval': paymentFailed?.paymentRetriesInterval,
        }, eventId: event.id);
        break;

      case Action.waitingSellerToPay:
        // Navigation logic
        final isUserCreator = _isUserCreator();
        final isBuyOrder = state.order?.kind == OrderType.buy;
        if (!(isUserCreator && isBuyOrder)) {
          navProvider.go('/trade_detail/$orderId');
        }
        
        // Notification
        sendNotification(event.action, values: {
          'expiration_seconds': mostroInstance?.expirationSeconds ?? Config.expirationSeconds,
        }, eventId: event.id);
        break;

      case Action.waitingBuyerInvoice:
        // Notification
        sendNotification(event.action, values: {
          'expiration_seconds': mostroInstance?.expirationSeconds ?? Config.expirationSeconds,
        }, eventId: event.id);
        
        // Navigation logic
        final isUserCreator = _isUserCreator();
        final isSellOrder = state.order?.kind == OrderType.sell;
        if (!(isUserCreator && isSellOrder)) {
          navProvider.go('/trade_detail/$orderId');
        }
        break;

      case Action.fiatSentOk:
        final peer = event.getPayload<Peer>();
        final isSeller = (session.role == Role.seller);
        
        // Notification (seller only)
        if (isSeller) {
          final buyerNym = peer?.publicKey != null 
              ? ref.read(nickNameProvider(peer!.publicKey)) 
              : 'Unknown';
          sendNotification(event.action, values: {
            'buyer_npub': buyerNym,
          }, eventId: event.id);
        }
        break;

      case Action.released:
        // Notification
        final sellerNym = state.order?.sellerTradePubkey != null 
            ? ref.read(nickNameProvider(state.order!.sellerTradePubkey!)) 
            : 'Unknown';
        sendNotification(event.action, values: {
          'seller_npub': sellerNym,
        }, eventId: event.id);
        break;

      case Action.purchaseCompleted:
        sendNotification(event.action, eventId: event.id);
        break;

      case Action.canceled:
        // Cleanup
        ref.read(mostroStorageProvider).deleteAllMessagesByOrderId(orderId);
        ref.read(sessionNotifierProvider.notifier).deleteSession(orderId);
        
        // Navigate and invalidate
        navProvider.go('/order_book');
        ref.invalidateSelf();
        break;

      case Action.cooperativeCancelInitiatedByYou:
        sendNotification(event.action, eventId: event.id);
        break;

      case Action.cooperativeCancelInitiatedByPeer:
        sendNotification(event.action, eventId: event.id);
        break;

      case Action.disputeInitiatedByYou:
        final dispute = event.getPayload<Dispute>();
        if (dispute == null) {
          logger.e('disputeInitiatedByYou: Missing Dispute payload for event ${event.id} with action ${event.action}');
          return;
        }
        sendNotification(event.action, values: {
          'user_token': dispute.disputeId,
        }, eventId: event.id);
        break;

      case Action.disputeInitiatedByPeer:
        final dispute = event.getPayload<Dispute>();
        if (dispute == null) {
          logger.e('disputeInitiatedByPeer: Missing Dispute payload for event ${event.id} with action ${event.action}');
          return;
        }
        sendNotification(event.action, values: {
          'user_token': dispute.disputeId,
        }, eventId: event.id);
        break;

      case Action.adminSettled:
        sendNotification(event.action, eventId: event.id);
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
        // Temp Notification 
        sendNotification(event.action, values: {
          'action': cantDo?.cantDoReason.toString(),
        }, isTemporary: true);
        break;

      case Action.rate:
        sendNotification(event.action, eventId: event.id);
        break;

      case Action.rateReceived:
        break;

      case Action.timeoutReversal:
        break;

      // Default
      default:
        // Skip cant-do events as they are already handled in explicit case above.
        if (event.action != Action.cantDo) {
          sendNotification(event.action, isTemporary: true);
        }
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

  @override
  void dispose() {
    subscription?.close();
    super.dispose();
  }
}
