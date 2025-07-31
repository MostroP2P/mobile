import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';
import 'package:mostro_mobile/shared/providers.dart';
import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/features/mostro/mostro_instance.dart';
import 'package:mostro_mobile/features/notifications/providers/notifications_provider.dart';
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
    final notifProvider = ref.read(notificationsProvider.notifier);
    final mostroInstance = ref.read(orderRepositoryProvider).mostroInstance;

    switch (event.action) {
      case Action.payInvoice:
        if (event.payload is PaymentRequest) {
          navProvider.go('/pay_invoice/${event.id!}');
        }
        break;
      case Action.fiatSentOk:
        final peer = event.getPayload<Peer>();
        notifProvider.notifyBoth(event.action, values: {
          'buyer_npub': peer?.publicKey ?? 'Unknown',
        }, orderId: orderId);
        break;
      case Action.released:
        notifProvider.notifyBoth(event.action, values: {
          'seller_npub': '',
        }, orderId: orderId);
        break;
      case Action.canceled:
        ref.read(mostroStorageProvider).deleteAllMessagesByOrderId(orderId);
        ref.read(sessionNotifierProvider.notifier).deleteSession(orderId);
        navProvider.go('/order_book');
        notifProvider.showTemporary(event.action, values: {'id': orderId});
        ref.invalidateSelf();
        break;
      case Action.cooperativeCancelInitiatedByYou:
        notifProvider.notifyBoth(event.action, values: {
          'id': event.id,
        }, orderId: orderId);
        break;
      case Action.cooperativeCancelInitiatedByPeer:
        notifProvider.notifyBoth(event.action, values: {
          'id': event.id!,
        }, orderId: orderId);
        break;
      case Action.disputeInitiatedByYou:
        final dispute = event.getPayload<Dispute>()!;
        notifProvider.notifyBoth(event.action, values: {
          'id': event.id!,
          'user_token': dispute.disputeId,
        }, orderId: orderId);
        break;
      case Action.disputeInitiatedByPeer:
        final dispute = event.getPayload<Dispute>()!;
        notifProvider.notifyBoth(event.action, values: {
          'id': event.id!,
          'user_token': dispute.disputeId,
        }, orderId: orderId);
        break;
      case Action.cooperativeCancelAccepted:
        notifProvider.showTemporary(event.action, values: {
          'id': event.id!,
        });
        break;
      case Action.holdInvoicePaymentAccepted:
        final order = event.getPayload<Order>();
        notifProvider.notifyBoth(event.action, values: {
          'seller_npub': order?.sellerTradePubkey ?? 'Unknown',
          'id': order?.id,
          'fiat_code': order?.fiatCode,
          'fiat_amount': order?.fiatAmount,
          'payment_method': order?.paymentMethod,
        }, orderId: orderId);
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
        notifProvider.notifyBoth(event.action, values: {
          'buyer_npub': state.order?.buyerTradePubkey ?? 'Unknown',
        }, orderId: orderId);
        navProvider.go('/trade_detail/$orderId');
        break;
      case Action.waitingSellerToPay:
        navProvider.go('/trade_detail/$orderId');
        notifProvider.showTemporary(event.action, values: {
          'id': event.id,
          'expiration_seconds':
              mostroInstance?.expirationSeconds ?? Config.expirationSeconds,
        });
        break;
      case Action.waitingBuyerInvoice:
        notifProvider.showTemporary(event.action, values: {
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
        notifProvider.notifyBoth(event.action, values: {
          'action': cantDo?.cantDoReason.toString(),
        }, orderId: orderId);
        break;
      case Action.adminSettled:
        notifProvider.notifyBoth(event.action, values: {}, orderId: orderId);
        break;
      case Action.paymentFailed:
        notifProvider.notifyBoth(event.action, values: {
          'payment_attempts': -1,
          'payment_retries_interval': -1000
        }, orderId: orderId);
        break;
      default:
        notifProvider.showTemporary(event.action, values: {});
        break;
    }
  }

  @override
  void dispose() {
    subscription?.close();
    super.dispose();
  }
}
