import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as actions;
import 'package:mostro_mobile/features/mostro/mostro_instance.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/providers.dart';
import 'package:mostro_mobile/shared/providers/legible_handle_provider.dart';
import 'package:mostro_mobile/shared/widgets/custom_card.dart';
import 'package:mostro_mobile/shared/utils/text_formatting.dart';

class MostroMessageDetail extends ConsumerWidget {
  final String orderId;
  const MostroMessageDetail({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderState = ref.watch(orderNotifierProvider(orderId));

    final actionText = _getActionText(
      context,
      ref,
    );
    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Colors.grey,
            foregroundImage: AssetImage('assets/images/launcher-icon.png'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: formatTextWithBoldUsernames(actionText, context),
                ),
                const SizedBox(height: 16),
                Text('${orderState.status} - ${orderState.action}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getActionText(
    BuildContext context,
    WidgetRef ref,
  ) {
    final tradeState = ref.watch(orderNotifierProvider(orderId));
    final action = tradeState.action;
    final orderPayload = tradeState.order;
    switch (action) {
      case actions.Action.newOrder:
        final expHrs =
            ref.read(orderRepositoryProvider).mostroInstance?.expirationHours ??
                '24';
        return S.of(context)!.newOrder(expHrs.toString());
      case actions.Action.canceled:
        return S.of(context)!.canceled(orderPayload?.id ?? '');
      case actions.Action.payInvoice:
        final expSecs = ref
                .read(orderRepositoryProvider)
                .mostroInstance
                ?.expirationSeconds ??
            900;
        final expMinutes = (expSecs / 60).round();
        return S.of(context)!.payInvoice(
              orderPayload?.amount.toString() ?? '',
              expMinutes,
              orderPayload?.fiatAmount.toString() ?? '',
              orderPayload?.fiatCode ?? '',
            );
      case actions.Action.addInvoice:
        final expSecs = ref
                .read(orderRepositoryProvider)
                .mostroInstance
                ?.expirationSeconds ??
            900;
        final expMinutes = (expSecs / 60).round();
        // Check if we're in payment-failed state to show different message
        if (tradeState.status == Status.paymentFailed) {
          return S.of(context)!.addInvoicePaymentFailed(
                orderPayload?.amount.toString() ?? '',
                orderPayload?.fiatAmount.toString() ?? '',
                orderPayload?.fiatCode ?? '',
              );
        }
        return S.of(context)!.addInvoice(
              orderPayload?.amount.toString() ?? '',
              expMinutes,
              orderPayload?.fiatAmount.toString() ?? '',
              orderPayload?.fiatCode ?? '',
            );
      case actions.Action.waitingSellerToPay:
        final expSecs = ref
                .read(orderRepositoryProvider)
                .mostroInstance
                ?.expirationSeconds ??
            900;
        final expMinutes = (expSecs / 60).round();

        // Check if user is the maker (creator) of the order
        final session = ref.watch(sessionProvider(orderPayload?.id ?? ''));
        final isUserCreator = _isUserCreator(session, tradeState);

        if (isUserCreator) {
          // Maker scenario: user created a buy order, show waiting for taker message
          return S
              .of(context)!
              .orderTakenWaitingCounterpart(expMinutes)
              .replaceAll('\\n', '\n');
        } else {
          // Taker scenario: user took someone's order, show original message
          return S
              .of(context)!
              .waitingSellerToPay(expMinutes, orderPayload?.id ?? '');
        }
      case actions.Action.waitingBuyerInvoice:
        final expSecs = ref
                .read(orderRepositoryProvider)
                .mostroInstance
                ?.expirationSeconds ??
            900;
        final expMinutes = (expSecs / 60).round();

        // Check if user is the maker (creator) of a sell order
        final session = ref.watch(sessionProvider(orderPayload?.id ?? ''));
        final isUserCreator = _isUserCreator(session, tradeState);
        final isSellOrder = tradeState.order?.kind == OrderType.sell;

        if (isUserCreator && isSellOrder) {
          // Maker scenario: user created a sell order, show waiting for taker message
          return S
              .of(context)!
              .orderTakenWaitingCounterpart(expMinutes)
              .replaceAll('\\n', '\n');
        } else {
          // Taker scenario: user took someone's order, show original message
          return S.of(context)!.waitingBuyerInvoice(expMinutes);
        }
      case actions.Action.buyerInvoiceAccepted:
        return S.of(context)!.buyerInvoiceAccepted;
      case actions.Action.holdInvoicePaymentAccepted:
        final session = ref.watch(sessionProvider(orderPayload?.id ?? ''));
        final sellerName = session?.peer?.publicKey != null
            ? ref.watch(nickNameProvider(session!.peer!.publicKey))
            : '';
        return S.of(context)!.holdInvoicePaymentAccepted(
              orderPayload?.fiatAmount.toString() ?? '',
              orderPayload?.fiatCode ?? '',
              orderPayload != null
                  ? orderPayload.paymentMethod
                  : 'No payment method',
              sellerName,
            );
      case actions.Action.buyerTookOrder:
        final buyerName = tradeState.peer?.publicKey != null
            ? ref.watch(nickNameProvider(tradeState.peer!.publicKey))
            : '';
        return S.of(context)!.buyerTookOrder(
              buyerName,
              orderPayload!.fiatAmount.toString(),
              orderPayload.fiatCode,
              orderPayload.paymentMethod,
            );
      case actions.Action.fiatSentOk:
        final session = ref.watch(sessionProvider(orderPayload!.id ?? ''));
        final peerName = tradeState.peer?.publicKey != null
            ? ref.watch(nickNameProvider(tradeState.peer!.publicKey))
            : '';
        return session!.role == Role.buyer
            ? S.of(context)!.fiatSentOkBuyer(peerName)
            : S.of(context)!.fiatSentOkSeller(peerName);
      case actions.Action.released:
        final sellerName = tradeState.peer?.publicKey != null
            ? ref.watch(nickNameProvider(tradeState.peer!.publicKey))
            : '';
        return S.of(context)!.released(sellerName);
      case actions.Action.purchaseCompleted:
        return S.of(context)!.purchaseCompleted;
      case actions.Action.holdInvoicePaymentSettled:
        final buyerName = tradeState.peer?.publicKey != null
            ? ref.watch(nickNameProvider(tradeState.peer!.publicKey))
            : '';
        return S.of(context)!.holdInvoicePaymentSettled(buyerName);
      case actions.Action.rate:
        return S.of(context)!.rate;
      case actions.Action.rateReceived:
        return S.of(context)!.rateReceived;
      case actions.Action.cooperativeCancelInitiatedByYou:
        return S
            .of(context)!
            .cooperativeCancelInitiatedByYou(orderPayload!.id ?? '');
      case actions.Action.cooperativeCancelInitiatedByPeer:
        return S
            .of(context)!
            .cooperativeCancelInitiatedByPeer(orderPayload!.id ?? '');
      case actions.Action.cooperativeCancelAccepted:
        return S.of(context)!.cooperativeCancelAccepted(orderPayload!.id ?? '');
      case actions.Action.disputeInitiatedByYou:
        final payload = ref.read(orderNotifierProvider(orderId)).dispute;
        return S
            .of(context)!
            .disputeInitiatedByYou(orderPayload!.id!, payload!.disputeId);
      case actions.Action.disputeInitiatedByPeer:
        final payload = ref.read(orderNotifierProvider(orderId)).dispute;
        return S
            .of(context)!
            .disputeInitiatedByPeer(orderPayload!.id!, payload!.disputeId);
      case actions.Action.adminTookDispute:
        return S.of(context)!.adminTookDisputeUsers;
      case actions.Action.adminCanceled:
        return S.of(context)!.adminCanceledUsers(orderPayload!.id ?? '');
      case actions.Action.adminSettled:
        return S.of(context)!.adminSettledUsers(orderPayload!.id ?? '');
      case actions.Action.paymentFailed:
        final payload = ref.read(orderNotifierProvider(orderId)).paymentFailed;
        final intervalInMinutes =
            ((payload?.paymentRetriesInterval ?? 0) / 60).round();
        return S.of(context)!.paymentFailed(
              payload?.paymentAttempts ?? 0,
              intervalInMinutes,
            );
      case actions.Action.invoiceUpdated:
        return S.of(context)!.invoiceUpdated;
      case actions.Action.holdInvoicePaymentCanceled:
        return S.of(context)!.holdInvoicePaymentCanceled;
      case actions.Action.cantDo:
        return _getCantDoMessage(context, ref);
      default:
        return 'No message found for action ${tradeState.action}'; // This is a fallback message for developers
    }
  }

  String _getCantDoMessage(BuildContext context, WidgetRef ref) {
    final tradeState = ref.watch(orderNotifierProvider(orderId));
    final cantDo = tradeState.cantDo;
    if (cantDo == null) {
      return '';
    }
    switch (cantDo.cantDoReason) {
      case CantDoReason.invalidSignature:
        return S.of(context)!.invalidSignature;
      case CantDoReason.notAllowedByStatus:
        return S.of(context)!.notAllowedByStatus;
      case CantDoReason.outOfRangeFiatAmount:
        return S.of(context)!.outOfRangeFiatAmount;
      case CantDoReason.outOfRangeSatsAmount:
        return S.of(context)!.outOfRangeSatsAmount;
      case CantDoReason.isNotYourDispute:
        return S.of(context)!.isNotYourDispute;
      case CantDoReason.disputeCreationError:
        return S.of(context)!.disputeCreationError;
      case CantDoReason.invalidDisputeStatus:
        return S.of(context)!.invalidDisputeStatus;
      case CantDoReason.invalidAction:
        return S.of(context)!.invalidAction;
      case CantDoReason.pendingOrderExists:
        return S.of(context)!.pendingOrderExists;
      default:
        return '${tradeState.status.toString()} - ${tradeState.action}';
    }
  }

  bool _isUserCreator(Session? session, OrderState tradeState) {
    if (session == null || session.role == null || tradeState.order == null) {
      return false;
    }
    return session.role == Role.buyer
        ? tradeState.order!.kind == OrderType.buy
        : tradeState.order!.kind == OrderType.sell;
  }
}
