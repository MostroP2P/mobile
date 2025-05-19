import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';
import 'package:mostro_mobile/shared/providers.dart';
import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/features/mostro/mostro_instance.dart';

class AbstractMostroNotifier extends StateNotifier<OrderState> {
  final String orderId;
  final Ref ref;
  final logger = Logger();

  late Session session;

  ProviderSubscription<AsyncValue<MostroMessage?>>? subscription;

  AbstractMostroNotifier(
    this.orderId,
    this.ref,
  ) : super(OrderState(
            action: Action.newOrder, status: Status.pending, order: null));

  void subscribe() {
    subscription = ref.listen(
      mostroMessageStreamProvider(orderId),
      (_, next) {
        next.when(
          data: (MostroMessage? msg) {
            if (msg != null) {
              handleEvent(msg);
            }
          },
          error: (error, stack) => handleError(error, stack),
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
        state = OrderState(
          action: event.action,
          status: event.getPayload<Order>()!.status,
          order: event.getPayload<Order>()!,
        );
        break;
      case Action.payInvoice:
        state = OrderState(
          action: event.action,
          status: event.getPayload<Order>()!.status,
          order: event.getPayload<Order>()!,
        );
        navProvider.go('/pay_invoice/${event.id!}');
        break;
      case Action.fiatSentOk:
        state = OrderState(
          action: event.action,
          status: event.getPayload<Order>()!.status,
          order: event.getPayload<Order>()!,
        );
        final peer = event.getPayload<Peer>();
        notifProvider.showInformation(event.action, values: {
          'buyer_npub': peer?.publicKey ?? '{buyer_npub}',
        });
        break;
      case Action.released:
        state = OrderState(
          action: event.action,
          status: event.getPayload<Order>()!.status,
          order: event.getPayload<Order>()!,
        );
        notifProvider.showInformation(event.action, values: {
          'seller_npub': '',
        });
        break;
      case Action.canceled:
        state = OrderState(
          action: event.action,
          status: event.getPayload<Order>()!.status,
          order: event.getPayload<Order>()!,
        );
        ref
            .read(mostroStorageProvider)
            .deleteAllMessagesByOrderId(session.orderId!);
        ref
            .read(sessionNotifierProvider.notifier)
            .deleteSession(session.orderId!);
        navProvider.go('/');
        notifProvider.showInformation(event.action, values: {'id': orderId});
        dispose();
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
          'user_token': dispute.disputeId,
        });
        break;
      case Action.disputeInitiatedByPeer:
        final dispute = event.getPayload<Dispute>()!;
        notifProvider.showInformation(event.action, values: {
          'id': event.id!,
          'user_token': dispute.disputeId,
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
        final peer = Peer(publicKey: order!.sellerTradePubkey!);
        sessionProvider.updateSession(
          orderId,
          (s) => s.peer = peer,
        );
        final chat = ref.read(chatRoomsProvider(orderId).notifier);
        chat.subscribe();
        break;
      case Action.holdInvoicePaymentSettled:
        notifProvider.showInformation(event.action, values: {
          'buyer_npub': 'buyerTradePubkey',
        });
        break;
      case Action.waitingSellerToPay:
        navProvider.go('/');
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
        break;
      case Action.addInvoice:
        navProvider.go('/add_invoice/$orderId');
        break;
      case Action.buyerTookOrder:
        final order = event.getPayload<Order>();
        if (order == null) {
          logger.e('Buyer took order, but order is null');
          break;
        }
        notifProvider.showInformation(event.action, values: {
          'buyer_npub': order.buyerTradePubkey ?? 'Unknown',
          'fiat_code': order.fiatCode,
          'fiat_amount': order.fiatAmount,
          'payment_method': order.paymentMethod,
        });
        // add seller tradekey to session
        // open chat
        final sessionProvider = ref.read(sessionNotifierProvider.notifier);
        final peer = order.buyerTradePubkey != null
            ? Peer(publicKey: order.buyerTradePubkey!)
            : null;
        sessionProvider.updateSession(
          orderId,
          (s) => s.peer = peer,
        );
        final chat = ref.read(chatRoomsProvider(orderId).notifier);
        chat.subscribe();
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
        notifProvider.showInformation(event.action, values: {
          'payment_attempts': -1,
          'payment_retries_interval': -1000
        });
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
