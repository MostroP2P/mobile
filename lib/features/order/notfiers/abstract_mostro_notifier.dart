import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/data/models/cant_do.dart';
import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/peer.dart';
import 'package:mostro_mobile/core/mostro_fsm.dart';
import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/features/mostro/mostro_instance.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:mostro_mobile/shared/providers/navigation_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/notification_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/providers/session_manager_provider.dart';

class AbstractMostroNotifier extends StateNotifier<MostroMessage> {
  final String orderId;
  final Ref ref;

  ProviderSubscription<AsyncValue<MostroMessage?>>? subscription;
  final logger = Logger();

  // Keep local FSM state in sync with every incoming MostroMessage.
  Status _currentStatus = Status.pending;

  Status get currentStatus => _currentStatus;

  AbstractMostroNotifier(
    this.orderId,
    this.ref,
  ) : super(MostroMessage(action: Action.newOrder, id: orderId));

  Future<void> sync() async {
    final storage = ref.read(mostroStorageProvider);
    final latestMessage = await storage.getMessageById(orderId);
    if (latestMessage != null) {
      state = latestMessage;
      // Bootstrap FSM status from the order payload if present.
      final orderPayload = latestMessage.getPayload<Order>();
      _currentStatus = orderPayload?.status ?? _currentStatus;
    }
  }

  void subscribe() {
    // Use the mostroMessageStream provider that directly watches Sembast storage changes
    subscription = ref.listen(
      mostroMessageStreamProvider(orderId),
      (_, AsyncValue<MostroMessage?> next) {
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
    // Update FSM first so UI can react to new `Status` if needed.
    _currentStatus = MostroFSM.nextStatus(_currentStatus, event.action);

    // Persist the message as the latest state for the order.
    state = event;

    handleOrderUpdate();
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
        // add seller tradekey to session
        // open chat
        final sessionProvider = ref.read(sessionNotifierProvider.notifier);
        final session = sessionProvider.getSessionByOrderId(orderId);
        session?.peer = Peer(publicKey: order!.buyerTradePubkey!);
        sessionProvider.saveSession(session!);
        final chat = ref.read(chatRoomsProvider(orderId).notifier);
        chat.subscribe();
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
        // add seller tradekey to session
        // open chat
        final sessionProvider = ref.read(sessionNotifierProvider.notifier);
        final session = sessionProvider.getSessionByOrderId(orderId);
        session?.peer = Peer(publicKey: order!.sellerTradePubkey!);
        sessionProvider.saveSession(session!);
        final chat = ref.read(chatRoomsProvider(orderId).notifier);
        chat.subscribe();
        break;
      case Action.fiatSentOk:
        final peer = state.getPayload<Peer>();
        notifProvider.showInformation(state.action, values: {
          'buyer_npub': peer?.publicKey ?? '{buyer_npub}',
        });
        break;
      case Action.holdInvoicePaymentSettled:
        notifProvider.showInformation(state.action, values: {
          'buyer_npub': 'buyerTradePubkey',
        });
        break;
      case Action.rate:
      case Action.rateReceived:
      case Action.cooperativeCancelInitiatedByYou:
        notifProvider.showInformation(state.action, values: {
          'id': state.id,
        });
        break;
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
      case Action.disputeInitiatedByYou:
        final dispute = state.getPayload<Dispute>()!;
        notifProvider.showInformation(state.action, values: {
          'id': state.id!,
          'user_token': dispute.disputeId,
        });
      case Action.cooperativeCancelAccepted:
        notifProvider.showInformation(state.action, values: {
          'id': state.id!,
        });
      case Action.cooperativeCancelInitiatedByPeer:
        notifProvider.showInformation(state.action, values: {
          'id': state.id!,
        });
      default:
        notifProvider.showInformation(state.action, values: {});
        break;
    }
  }

  @override
  void dispose() {
    subscription?.close();
    super.dispose();
  }
}
