import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/data/models/cant_do.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/enums/cant_do_reason.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/repositories/mostro_repository.dart';
import 'package:mostro_mobile/shared/providers/navigation_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/notification_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/features/mostro/mostro_instance.dart';

class AbstractOrderNotifier extends StateNotifier<MostroMessage> {
  final MostroRepository orderRepository;
  final Ref ref;
  final String orderId;
  StreamSubscription<MostroMessage>? orderSubscription;
  final logger = Logger();

  AbstractOrderNotifier(
    this.orderRepository,
    this.orderId,
    this.ref,
  ) : super(MostroMessage(action: Action.newOrder, id: orderId));

  Future<void> subscribe(Stream<MostroMessage> stream) async {
    try {
      orderSubscription = stream.listen((order) {
        state = order;
        handleOrderUpdate();
      });
    } catch (e) {
      handleError(e);
    }
  }

  void handleError(Object err) {
    logger.e(err);
    if (state.payload is CantDo) {
      final cantdo = state.getPayload<CantDo>()!;

      switch (cantdo.cantDoReason) {
        case CantDoReason.outOfRangeSatsAmount:
          break;
        case CantDoReason.outOfRangeFiatAmount:
          break;
        default:
      }
    }
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
        navProvider.go('/');
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
        navProvider.go('/');
        break;
      case Action.fiatSentOk:
      case Action.holdInvoicePaymentSettled:
      case Action.rate:
      case Action.rateReceived:
      case Action.cooperativeCancelInitiatedByYou:
        notifProvider.showInformation(state.action, values: {
          'id': state.id,
        });
        navProvider.go('/');
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
          'seller_npub': null,
        });

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
