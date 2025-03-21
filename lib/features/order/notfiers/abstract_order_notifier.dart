import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/data/models/cant_do.dart';
import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/peer.dart';
import 'package:mostro_mobile/services/mostro_service.dart';
import 'package:mostro_mobile/shared/providers/navigation_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/notification_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/features/mostro/mostro_instance.dart';

class AbstractOrderNotifier extends StateNotifier<MostroMessage> {
  final MostroService mostroService;
  final Ref ref;
  final String orderId;
  StreamSubscription<MostroMessage>? orderSubscription;
  final logger = Logger();
  Order? order;
  Peer? peer;

  AbstractOrderNotifier(
    this.mostroService,
    this.orderId,
    this.ref,
  ) : super(MostroMessage(action: Action.newOrder, id: orderId));

  Future<void> subscribe(Stream<MostroMessage> stream) async {
    try {
      orderSubscription = stream.listen((event) {
        if (event.payload is CantDo) {
          handleCantDo(event.getPayload<CantDo>());
          return;
        }
        state = event;
        event.payload is Order ? order = event.getPayload<Order>() : null;
        event.payload is Peer ? peer = event.getPayload<Peer>() : null;
        handleOrderUpdate();
      });
    } catch (e) {
      handleError(e);
    }
  }

  void handleError(Object err) {
    logger.e(err);
  }

  void handleCantDo(CantDo? cantDo) {
    final notifProvider = ref.read(notificationProvider.notifier);
    notifProvider.showInformation(Action.cantDo, values: {
      'action': cantDo?.cantDoReason.toString(),
    });
  }

  void handleOrderUpdate() {
    final navProvider = ref.read(navigationProvider.notifier);
    final notifProvider = ref.read(notificationProvider.notifier);
    final mostroInstance = ref.read(orderRepositoryProvider).mostroInstance;

    switch (state.action) {
      case Action.addInvoice:
        navProvider.go('/add_invoice/$orderId');
        break;
      case Action.cantDo:
        final cantDo = state.getPayload<CantDo>();
        notifProvider.showInformation(state.action,
            values: {'action': cantDo?.cantDoReason.toString()});
        break;
      case Action.newOrder:
        navProvider.go('/order_confirmed/${state.id!}');
        break;
      case Action.payInvoice:
        navProvider.go('/pay_invoice/${state.id!}');
        break;
      case Action.waitingSellerToPay:
        navProvider.go('/');
        notifProvider.showInformation(state.action, values: {
          'id': state.id,
          'expiration_seconds':
              mostroInstance?.expirationSeconds ?? Config.expirationSeconds,
        });
        break;
      case Action.waitingBuyerInvoice:
        notifProvider.showInformation(state.action, values: {
          'expiration_seconds':
              mostroInstance?.expirationSeconds ?? Config.expirationSeconds,
        });
        break;
      case Action.buyerTookOrder:
        final order = state.getPayload<Order>();
        notifProvider.showInformation(state.action, values: {
          'buyer_npub': order?.buyerTradePubkey ?? 'Unknown',
          'fiat_code': order?.fiatCode,
          'fiat_amount': order?.fiatAmount,
          'payment_method': order?.paymentMethod,
        });
        break;
      case Action.canceled:
        navProvider.go('/');
        notifProvider.showInformation(state.action, values: {'id': orderId});
        break;
      case Action.holdInvoicePaymentAccepted:
        final order = state.getPayload<Order>();
        notifProvider.showInformation(state.action, values: {
          'seller_npub': order?.sellerTradePubkey ?? 'Unknown',
          'id': order?.id,
          'fiat_code': order?.fiatCode,
          'fiat_amount': order?.fiatAmount,
          'payment_method': order?.paymentMethod,
        });
        break;
      case Action.fiatSentOk:
        final peer = state.getPayload<Peer>();
        notifProvider.showInformation(state.action, values: {
          'buyer_npub': peer?.publicKey ?? '{buyer_npub}',
        });
        break;
      case Action.holdInvoicePaymentSettled:
        notifProvider.showInformation(state.action, values: {
          'buyer_npub': order?.buyerTradePubkey,
        });
        break;
      case Action.rate:
      case Action.rateReceived:
      case Action.cooperativeCancelInitiatedByYou:
        notifProvider.showInformation(state.action, values: {
          'id': state.id,
        });
        break;
      case Action.disputeInitiatedByYou:
      case Action.adminSettled:
        notifProvider.showInformation(state.action, values: {});
        break;
      case Action.paymentFailed:
        notifProvider.showInformation(state.action, values: {
          'payment_attempts': -1,
          'payment_retries_interval': -1000
        });
        break;
      case Action.released:
        notifProvider.showInformation(state.action, values: {
          'seller_npub': '',
        });
      case Action.disputeInitiatedByPeer:
        final dispute = state.getPayload<Dispute>()!;
        notifProvider.showInformation(state.action, values: {
          'id': state.id!,
          'user_token': dispute.disputeId,
        });
        break;
      default:
        notifProvider.showInformation(state.action, values: {});
        break;
    }
  }

  @override
  void dispose() {
    orderSubscription?.cancel();
    super.dispose();
  }
}
