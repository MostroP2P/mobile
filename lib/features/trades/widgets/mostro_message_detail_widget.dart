import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as actions;
import 'package:mostro_mobile/features/mostro/mostro_instance.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/providers.dart';
import 'package:mostro_mobile/shared/widgets/custom_card.dart';

class MostroMessageDetail extends ConsumerWidget {
  final String orderId;
  const MostroMessageDetail({super.key, required this.orderId});

  /// Helper function to format payment methods for display
  /// Returns "method1 (+X más)" if multiple methods, or just "method1" if single
  String _formatPaymentMethods(List<String> paymentMethods, BuildContext context) {
    if (paymentMethods.isEmpty) {
      return S.of(context)!.noPaymentMethod;
    }

    if (paymentMethods.length == 1) {
      return paymentMethods.first;
    }

    final additionalCount = paymentMethods.length - 1;
    return '${paymentMethods.first} (+$additionalCount más)';
  }

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
                Text(
                  actionText,
                  style: Theme.of(context).textTheme.bodyLarge,
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
            ref.read(orderRepositoryProvider).mostroInstance?.expiration ??
                '24';
        return S.of(context)!.newOrder(int.tryParse(expHrs) ?? 24);
      case actions.Action.canceled:
        return S.of(context)!.canceled(orderPayload?.id ?? '');
      case actions.Action.payInvoice:
        final expSecs = ref
                .read(orderRepositoryProvider)
                .mostroInstance
                ?.expirationSeconds ??
            900;
        return S.of(context)!.payInvoice(
              orderPayload?.amount.toString() ?? '',
              '${expSecs ~/ 60} minutes',
              orderPayload?.fiatAmount.toString() ?? '',
              orderPayload?.fiatCode ?? '',
            );
      case actions.Action.addInvoice:
        final expSecs = ref
                .read(orderRepositoryProvider)
                .mostroInstance
                ?.expirationSeconds ??
            900;
        return S.of(context)!.addInvoice(
              orderPayload?.amount.toString() ?? '',
              orderPayload?.fiatCode ?? '',
              orderPayload?.fiatAmount.toString() ?? '',
              expSecs,
            );
      case actions.Action.waitingSellerToPay:
        final expSecs = ref
                .read(orderRepositoryProvider)
                .mostroInstance
                ?.expirationSeconds ??
            900;
        return S
            .of(context)!
            .waitingSellerToPay(orderPayload?.id ?? '', expSecs);
      case actions.Action.waitingBuyerInvoice:
        final expSecs = ref
                .read(orderRepositoryProvider)
                .mostroInstance
                ?.expirationSeconds ??
            900;
        return S.of(context)!.waitingBuyerInvoice(expSecs);
      case actions.Action.buyerInvoiceAccepted:
        return S.of(context)!.buyerInvoiceAccepted;
      case actions.Action.holdInvoicePaymentAccepted:
        final session = ref.watch(sessionProvider(orderPayload?.id ?? ''));
        return S.of(context)!.holdInvoicePaymentAccepted(
              orderPayload?.fiatAmount.toString() ?? '',
              orderPayload?.fiatCode ?? '',
              orderPayload != null
                  ? orderPayload.paymentMethod
                  : 'No payment method',
              session?.peer?.publicKey ?? '',
            );
      case actions.Action.buyerTookOrder:
        return S.of(context)!.buyerTookOrder(
              tradeState.peer?.publicKey ?? '',
              orderPayload!.fiatCode,
              orderPayload.fiatAmount.toString(),
              orderPayload.paymentMethod,
            );
      case actions.Action.fiatSentOk:
        final session = ref.watch(sessionProvider(orderPayload!.id ?? ''));
        return session!.role == Role.buyer
            ? S.of(context)!.fiatSentOkBuyer(tradeState.peer!.publicKey)
            : S.of(context)!.fiatSentOkSeller(tradeState.peer!.publicKey);
      case actions.Action.released:
        return S.of(context)!.released('{seller_npub}');
      case actions.Action.purchaseCompleted:
        return S.of(context)!.purchaseCompleted;
      case actions.Action.holdInvoicePaymentSettled:
        return S.of(context)!.holdInvoicePaymentSettled('{buyer_npub}');
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
        return S.of(context)!.adminTookDisputeUsers('{admin token}');
      case actions.Action.adminCanceled:
        return S.of(context)!.adminCanceledUsers(orderPayload!.id ?? '');
      case actions.Action.adminSettled:
        return S.of(context)!.adminSettledUsers(orderPayload!.id ?? '');
      case actions.Action.paymentFailed:
        return S.of(context)!.paymentFailed('{attempts}', '{retries}');
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
        return S.of(context)!.notAllowedByStatus(
              orderId,
              tradeState.status,
            );
      case CantDoReason.outOfRangeFiatAmount:
        return S.of(context)!.outOfRangeFiatAmount('{fiat_min}', '{fiat_max}');
      case CantDoReason.outOfRangeSatsAmount:
        final mostroInstance = ref.read(orderRepositoryProvider).mostroInstance;
        return S.of(context)!.outOfRangeSatsAmount(
            mostroInstance!.maxOrderAmount, mostroInstance.minOrderAmount);
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
}
