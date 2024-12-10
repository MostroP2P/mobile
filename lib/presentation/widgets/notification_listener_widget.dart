import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/features/add_order/screens/order_confirmation_screen.dart';
import 'package:mostro_mobile/features/take_order/screens/add_lightning_invoice_screen.dart';
import 'package:mostro_mobile/notifiers/global_notification_notifier.dart';
import 'package:mostro_mobile/providers/event_store_providers.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as actions;

class NotificationListenerWidget extends ConsumerWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigator;

  const NotificationListenerWidget({super.key, required this.child, required this.navigator});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<NotificationState>(globalNotificationProvider, (previous, next) {
      final event = next.message;

      switch (event?.action) {
        // New Sell/Buy Order
        case actions.Action.newOrder:
          navigator.currentState!.push(
            MaterialPageRoute(
              builder: (context) =>
                  OrderConfirmationScreen(orderId: event!.requestId!),
            ),
          );
          break;

        case actions.Action.addInvoice:
          if (event?.payload != null && event?.payload is Order) {
            final Order order = event?.payload as Order;
            if (order.status == Status.waitingBuyerInvoice) {
              // Seller pays hold invoice
              // Take Buy Order
              // Notify User
            } else {
              // Take Sell Order
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => AddLightningInvoiceScreen(
                      event!.requestId!, order.amount),
                ),
              );
            }
          }
          break;

        case actions.Action.waitingBuyerInvoice:
          // Notify User
          // Take Buy Order
          // Seller pays hold invoice
          break;

        case actions.Action.waitingSellerToPay:
          // End notification for
          // Take Sell Order
          break;

        case actions.Action.payInvoice:
          // Go to payment screen
          // Take Buy Order
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  OrderConfirmationScreen(orderId: event!.requestId!),
            ),
          );
          break;

        case actions.Action.buyerTookOrder:
          // Seller pays hold invoice
          // Keys are swapperd
          break;

        case actions.Action.holdInvoicePaymentAccepted:
          // TODO: Handle this case.
          break;

        case actions.Action.fiatSentOk:
          // TODO: Handle this case.
          break;

        case actions.Action.holdInvoicePaymentSettled:
          // TODO: Handle this case.
          break;

        case actions.Action.released:
          // TODO: Handle this case.
          break;

        case actions.Action.purchaseCompleted:
          // TODO: Handle this case.
          break;

        case actions.Action.rate:
          // TODO: Handle this case.
          break;
        case actions.Action.rateReceived:
          // TODO: Handle this case.
          break;

        case actions.Action.canceled:
          // TODO: Handle this case.
          break;

        case actions.Action.cooperativeCancelInitiatedByYou:
        // TODO: Handle this case.
        case actions.Action.cooperativeCancelInitiatedByPeer:
        // TODO: Handle this case.
        case actions.Action.cooperativeCancelAccepted:
        // TODO: Handle this case.

        case actions.Action.disputeInitiatedByYou:
        // TODO: Handle this case.
        case actions.Action.disputeInitiatedByPeer:
        // TODO: Handle this case.
        case actions.Action.adminSettled:
        // TODO: Handle this case.
        case actions.Action.adminCanceled:
        // TODO: Handle this case.

        case actions.Action.buyerInvoiceAccepted:
        // TODO: Handle this case.
        case actions.Action.holdInvoicePaymentCanceled:
        // TODO: Handle this case.
        case actions.Action.cantDo:
        // TODO: Handle this case.
        case actions.Action.adminCancel:
        // TODO: Handle this case.
        case actions.Action.isNotYourOrder:
        // TODO: Handle this case.
        case actions.Action.notAllowedByStatus:
        // TODO: Handle this case.
        case actions.Action.outOfRangeFiatAmount:
        // TODO: Handle this case.
        case actions.Action.isNotYourDispute:
        // TODO: Handle this case.
        case actions.Action.notFound:
        // TODO: Handle this case.
        case actions.Action.incorrectInvoiceAmount:
        // TODO: Handle this case.
        case actions.Action.invalidSatsAmount:
        // TODO: Handle this case.
        case actions.Action.outOfRangeSatsAmount:
        // TODO: Handle this case.
        case actions.Action.paymentFailed:
        // TODO: Handle this case.
        case actions.Action.invoiceUpdated:
        // TODO: Handle this case.
        default:
          break;
      }
    });

    // Ensure the rest of the widget tree is displayed
    return child;
  }
}
