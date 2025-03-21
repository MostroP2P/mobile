import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/cant_do.dart';
import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/data/models/enums/cant_do_reason.dart';
import 'package:mostro_mobile/data/models/enums/role.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/peer.dart';
import 'package:mostro_mobile/features/mostro/mostro_instance.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as actions;
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/providers/session_manager_provider.dart';
import 'package:mostro_mobile/shared/widgets/custom_card.dart';

class MostroMessageDetail extends ConsumerWidget {
  final NostrEvent order;

  const MostroMessageDetail({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Retrieve the MostroMessage using the order's orderId
    final mostroMessage = ref.watch(orderNotifierProvider(order.orderId!));
    final session = ref.watch(sessionProvider(order.orderId!));
    // Map the action enum to the corresponding i10n string.
    String actionText;
    switch (mostroMessage.action) {
      case actions.Action.newOrder:
        final expHrs =
            ref.read(orderRepositoryProvider).mostroInstance?.expiration ??
                '24';
        actionText = S.of(context)!.newOrder(int.tryParse(expHrs) ?? 24);
        break;
      case actions.Action.canceled:
        actionText = S.of(context)!.canceled(order.orderId!);
        break;
      case actions.Action.payInvoice:
        final expSecs = ref
                .read(orderRepositoryProvider)
                .mostroInstance
                ?.expirationSeconds ??
            900;
        actionText = S.of(context)!.payInvoice(
            order.amount!, order.currency!, order.fiatAmount.minimum, expSecs);
        break;
      case actions.Action.addInvoice:
        final expSecs = ref
                .read(orderRepositoryProvider)
                .mostroInstance
                ?.expirationSeconds ??
            900;
        actionText = S.of(context)!.addInvoice(
            order.amount!, order.currency!, order.fiatAmount.minimum, expSecs);
        break;
      case actions.Action.waitingSellerToPay:
        final expSecs = ref
                .read(orderRepositoryProvider)
                .mostroInstance
                ?.expirationSeconds ??
            900;
        actionText = S.of(context)!.waitingSellerToPay(order.orderId!, expSecs);
        break;
      case actions.Action.waitingBuyerInvoice:
        final expSecs = ref
                .read(orderRepositoryProvider)
                .mostroInstance
                ?.expirationSeconds ??
            900;
        actionText = S.of(context)!.waitingBuyerInvoice(expSecs);
        break;
      case actions.Action.buyerInvoiceAccepted:
        actionText = S.of(context)!.buyerInvoiceAccepted;
        break;
      case actions.Action.holdInvoicePaymentAccepted:
        final payload = mostroMessage.getPayload<Order>();
        actionText = S.of(context)!.holdInvoicePaymentAccepted(
              payload!.fiatAmount,
              payload.fiatCode,
              payload.paymentMethod,
              payload.sellerTradePubkey!,
            );
        break;
      case actions.Action.buyerTookOrder:
        final payload = mostroMessage.getPayload<Order>();
        actionText = S.of(context)!.buyerTookOrder(payload!.buyerTradePubkey!,
            payload.fiatCode, payload.fiatAmount, payload.paymentMethod);
        break;
      case actions.Action.fiatSentOk:
        final payload = mostroMessage.getPayload<Peer>();
        actionText = session!.role == Role.buyer
            ? S.of(context)!.fiatSentOkBuyer(payload!.publicKey)
            : S.of(context)!.fiatSentOkSeller(payload!.publicKey);
        break;
      case actions.Action.released:
        actionText = S.of(context)!.released('{seller_npub}');
        break;
      case actions.Action.purchaseCompleted:
        actionText = S.of(context)!.purchaseCompleted;
        break;
      case actions.Action.holdInvoicePaymentSettled:
        actionText = S
            .of(context)!
            .holdInvoicePaymentSettled('{buyer_npub}');
        break;
      case actions.Action.rate:
        actionText = S.of(context)!.rate;
        break;
      case actions.Action.rateReceived:
        actionText = S.of(context)!.rateReceived;
        break;
      case actions.Action.cooperativeCancelInitiatedByYou:
        actionText =
            S.of(context)!.cooperativeCancelInitiatedByYou(order.orderId!);
        break;
      case actions.Action.cooperativeCancelInitiatedByPeer:
        actionText =
            S.of(context)!.cooperativeCancelInitiatedByPeer(order.orderId!);
        break;
      case actions.Action.cooperativeCancelAccepted:
        actionText = S.of(context)!.cooperativeCancelAccepted(order.orderId!);
        break;
      case actions.Action.disputeInitiatedByYou:
        final payload = mostroMessage.getPayload<Dispute>();
        actionText = S
            .of(context)!
            .disputeInitiatedByYou(order.orderId!, payload!.disputeId);
        break;
      case actions.Action.disputeInitiatedByPeer:
        final payload = mostroMessage.getPayload<Dispute>();
        actionText = S
            .of(context)!
            .disputeInitiatedByPeer(order.orderId!, payload!.disputeId);
        break;
      case actions.Action.adminTookDispute:
        //actionText = S.of(context)!.adminTookDisputeAdmin('');
        actionText = S.of(context)!.adminTookDisputeUsers('{admin token}');
        break;
      case actions.Action.adminCanceled:
        //actionText = S.of(context)!.adminCanceledAdmin('');
        actionText = S.of(context)!.adminCanceledUsers(order.orderId!);
        break;
      case actions.Action.adminSettled:
        //actionText = S.of(context)!.adminSettledAdmin;
        actionText = S.of(context)!.adminSettledUsers(order.orderId!);
        break;
      case actions.Action.paymentFailed:
        actionText = S.of(context)!.paymentFailed('{attempts}', '{retries}');
        break;
      case actions.Action.invoiceUpdated:
        actionText = S.of(context)!.invoiceUpdated;
        break;
      case actions.Action.holdInvoicePaymentCanceled:
        actionText = S.of(context)!.holdInvoicePaymentCanceled;
        break;
      case actions.Action.cantDo:
        final cantDo = mostroMessage.getPayload<CantDo>();
        switch (cantDo!.cantDoReason) {
          case CantDoReason.invalidSignature:
            actionText = S.of(context)!.invalidSignature;
            break;
          case CantDoReason.invalidTradeIndex:
            actionText = S.of(context)!.invalidTradeIndex;
            break;
          case CantDoReason.invalidAmount:
            actionText = S.of(context)!.invalidAmount;
            break;
          case CantDoReason.invalidInvoice:
            actionText = S.of(context)!.invalidInvoice;
            break;
          case CantDoReason.invalidPaymentRequest:
            actionText = S.of(context)!.invalidPaymentRequest;
            break;
          case CantDoReason.invalidPeer:
            actionText = S.of(context)!.invalidPeer;
            break;
          case CantDoReason.invalidRating:
            actionText = S.of(context)!.invalidRating;
            break;
          case CantDoReason.invalidTextMessage:
            actionText = S.of(context)!.invalidTextMessage;
            break;
          case CantDoReason.invalidOrderKind:
            actionText = S.of(context)!.invalidOrderKind;
            break;
          case CantDoReason.invalidOrderStatus:
            actionText = S.of(context)!.invalidOrderStatus;
            break;
          case CantDoReason.invalidPubkey:
            actionText = S.of(context)!.invalidPubkey;
            break;
          case CantDoReason.invalidParameters:
            actionText = S.of(context)!.invalidParameters;
            break;
          case CantDoReason.orderAlreadyCanceled:
            actionText = S.of(context)!.orderAlreadyCanceled;
            break;
          case CantDoReason.cantCreateUser:
            actionText = S.of(context)!.cantCreateUser;
            break;
          case CantDoReason.isNotYourOrder:
            actionText = S.of(context)!.isNotYourOrder;
            break;
          case CantDoReason.notAllowedByStatus:
            actionText =
                S.of(context)!.notAllowedByStatus(order.orderId!, order.status);
            break;
          case CantDoReason.outOfRangeFiatAmount:
            actionText =
                S.of(context)!.outOfRangeFiatAmount('{fiat_min}', '{fiat_max}');
            break;
          case CantDoReason.outOfRangeSatsAmount:
            final mostroInstance =
                ref.read(orderRepositoryProvider).mostroInstance;
            actionText = S.of(context)!.outOfRangeSatsAmount(
                mostroInstance!.maxOrderAmount, mostroInstance.minOrderAmount);
            break;
          case CantDoReason.isNotYourDispute:
            actionText = S.of(context)!.isNotYourDispute;
            break;
          case CantDoReason.disputeCreationError:
            actionText = S.of(context)!.disputeCreationError;
            break;
          case CantDoReason.notFound:
            actionText = S.of(context)!.notFound;
            break;
          case CantDoReason.invalidDisputeStatus:
            actionText = S.of(context)!.invalidDisputeStatus;
            break;
          case CantDoReason.invalidAction:
            actionText = S.of(context)!.invalidAction;
            break;
          case CantDoReason.pendingOrderExists:
            actionText = S.of(context)!.pendingOrderExists;
            break;
        }
        break;
      case actions.Action.adminAddSolver:
        actionText = S.of(context)!.adminAddSolver('{admin_solver}');
        break;
      default:
        actionText = '';
    }

    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppTheme.grey2,
            foregroundImage: AssetImage('assets/images/launcher-icon.png'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  actionText,
                  style: AppTheme.theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Text('${order.status} - ${mostroMessage.action}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
