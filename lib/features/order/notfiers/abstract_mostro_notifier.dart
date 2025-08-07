import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';
import 'package:mostro_mobile/shared/providers.dart';
import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/features/mostro/mostro_instance.dart';
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

  void handleEvent(MostroMessage event) {
    final navProvider = ref.read(navigationProvider.notifier);
    final notifProvider = ref.read(notificationProvider.notifier);
    final mostroInstance = ref.read(orderRepositoryProvider).mostroInstance;

    switch (event.action) {
      case Action.newOrder:
        break;
      case Action.payInvoice:
        if (event.payload is PaymentRequest) {
          navProvider.go('/pay_invoice/${event.id!}');
        }
        ref.read(sessionNotifierProvider.notifier).saveSession(session);
        break;
      case Action.fiatSentOk:
        final peer = event.getPayload<Peer>();
        notifProvider.showInformation(event.action, values: {
          'buyer_npub': peer?.publicKey ?? 'Unknown',
        });
        break;
      case Action.released:
        notifProvider.showInformation(event.action, values: {
          'seller_npub': '',
        });
        break;
      case Action.canceled:
        ref.read(mostroStorageProvider).deleteAllMessagesByOrderId(orderId);
        ref.read(sessionNotifierProvider.notifier).deleteSession(orderId);
        navProvider.go('/order_book');
        notifProvider.showInformation(event.action, values: {'id': orderId});
        ref.invalidateSelf();
        break;
      case Action.cooperativeCancelInitiatedByYou:
        notifProvider.showInformation(event.action, values: {
          'id': event.id,
        });
        break;
      case Action.cooperativeCancelInitiatedByPeer:
        notifProvider.showInformation(event.action, values: {
          'id': event.id!,
        });
        break;
      case Action.disputeInitiatedByYou:
        final dispute = event.getPayload<Dispute>()!;
        notifProvider.showInformation(event.action, values: {
          'id': event.id!,
          'user_token': dispute.disputeToken ?? dispute.disputeId,
        });
        break;
      case Action.disputeInitiatedByPeer:
        final dispute = event.getPayload<Dispute>()!;
        notifProvider.showInformation(event.action, values: {
          'id': event.id!,
          'user_token': dispute.disputeToken ?? dispute.disputeId,
        });
        break;
      case Action.cooperativeCancelAccepted:
        notifProvider.showInformation(event.action, values: {
          'id': event.id!,
        });
        break;
      case Action.holdInvoicePaymentAccepted:
        final order = event.getPayload<Order>();
        notifProvider.showInformation(event.action, values: {
          'seller_npub': order?.sellerTradePubkey ?? 'Unknown',
          'id': order?.id,
          'fiat_code': order?.fiatCode,
          'fiat_amount': order?.fiatAmount,
          'payment_method': order?.paymentMethod,
        });
        // add seller tradekey to session
        // open chat
        final sessionProvider = ref.read(sessionNotifierProvider.notifier);
        final peer = order!.sellerTradePubkey != null
            ? Peer(publicKey: order.sellerTradePubkey!)
            : null;
        sessionProvider.updateSession(
          orderId,
          (s) => s.peer = peer,
        );
        state = state.copyWith(
          peer: peer,
        );
        final chat = ref.read(chatRoomsProvider(orderId).notifier);
        chat.subscribe();
        break;
      case Action.holdInvoicePaymentSettled:
        notifProvider.showInformation(event.action, values: {
          'buyer_npub': state.order?.buyerTradePubkey ?? 'Unknown',
        });
        navProvider.go('/trade_detail/$orderId');
        break;
      case Action.waitingSellerToPay:
        navProvider.go('/trade_detail/$orderId');
        notifProvider.showInformation(event.action, values: {
          'id': event.id,
          'expiration_seconds':
              mostroInstance?.expirationSeconds ?? Config.expirationSeconds,
        });
        break;
      case Action.waitingBuyerInvoice:
        notifProvider.showInformation(event.action, values: {
          'expiration_seconds':
              mostroInstance?.expirationSeconds ?? Config.expirationSeconds,
        });
        navProvider.go('/trade_detail/$orderId');
        break;
      case Action.addInvoice:
        final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
        sessionNotifier.saveSession(session);

        navProvider.go('/add_invoice/$orderId');
        break;
      case Action.buyerTookOrder:
        final order = event.getPayload<Order>();
        if (order == null) {
          logger.e('Buyer took order, but order is null');
          break;
        }
        final sessionProvider = ref.read(sessionNotifierProvider.notifier);
        final peer = order.buyerTradePubkey != null
            ? Peer(publicKey: order.buyerTradePubkey!)
            : null;
        sessionProvider.updateSession(
          orderId,
          (s) => s.peer = peer,
        );
        state = state.copyWith(
          peer: peer,
        );
        final chat = ref.read(chatRoomsProvider(orderId).notifier);
        chat.subscribe();
        navProvider.go('/trade_detail/$orderId');
        break;
      case Action.cantDo:
        final cantDo = event.getPayload<CantDo>();
        ref.read(notificationProvider.notifier).showInformation(
          event.action,
          values: {
            'action': cantDo?.cantDoReason.toString(),
          },
        );
        break;
      case Action.adminSettled:
        notifProvider.showInformation(event.action, values: {});
        break;
      case Action.paymentFailed:
        final paymentFailed = event.getPayload<PaymentFailed>();
        notifProvider.showInformation(event.action, values: {
          'payment_attempts': paymentFailed?.paymentAttempts,
          'payment_retries_interval': paymentFailed?.paymentRetriesInterval,
        });
        break;
      case Action.timeoutReversal:
        // No automatic notification - handled manually in OrderNotifier
        break;
      default:
        notifProvider.showInformation(event.action, values: {});
        break;
    }
  }

  @override
  void dispose() {
    subscription?.close();
    super.dispose();
  }
}
