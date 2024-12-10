import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/features/add_order/screens/order_confirmation_screen.dart';
import 'package:mostro_mobile/features/take_order/screens/add_lightning_invoice_screen.dart';
import 'package:mostro_mobile/notifiers/global_notification_notifier.dart';
import 'package:mostro_mobile/providers/event_store_providers.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as actions;

class NotificationListenerWidget extends ConsumerWidget {
  final Widget child;

  const NotificationListenerWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<NotificationState>(globalNotificationProvider, (previous, next) {
      final event = next.message;

      switch (event?.action) {
        // New Sell/Buy Order
        case actions.Action.newOrder:
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  OrderConfirmationScreen(orderId: event!.requestId!),
            ),
          );
          break;

        case actions.Action.addInvoice:
          // Take Sell Order
          // Show Add Invoice Screen
          final Order order = event?.payload as Order;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AddLightningInvoiceScreen(
                event!.requestId!, order.amount
              ),
            ),
          );
          // Unless is

          break;

        case actions.Action.waitingBuyerInvoice:
        // TODO: Handle this case.

        case actions.Action.waitingSellerToPay:
        // TODO: Handle this case.

        case actions.Action.payInvoice:
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  OrderConfirmationScreen(orderId: event!.requestId!),
            ),
          );
          break;

        case actions.Action.buyerTookOrder:
          // TODO: Handle this case.
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
