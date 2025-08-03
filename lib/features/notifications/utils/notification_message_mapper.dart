import 'package:mostro_mobile/data/models/enums/action.dart';

/// Utility class to map Mostro actions to notification title and message keys
class NotificationMessageMapper {
  /// Maps an action to its corresponding notification title key
  static String getTitleKey(Action action) {
    switch (action) {
      case Action.newOrder:
        return 'notification_new_order_title';
      case Action.takeBuy:
      case Action.takeSell:
        return 'notification_order_taken_title';
      case Action.payInvoice:
        return 'notification_payment_required_title';
      case Action.fiatSent:
        return 'notification_fiat_sent_title';
      case Action.fiatSentOk:
        return 'notification_fiat_sent_ok_title';
      case Action.release:
        return 'notification_release_title';
      case Action.released:
        return 'notification_bitcoin_released_title';
      case Action.buyerInvoiceAccepted:
        return 'notification_buyer_invoice_accepted_title';
      case Action.purchaseCompleted:
        return 'notification_purchase_completed_title';
      case Action.holdInvoicePaymentAccepted:
        return 'notification_hold_invoice_payment_accepted_title';
      case Action.holdInvoicePaymentSettled:
        return 'notification_hold_invoice_payment_settled_title';
      case Action.holdInvoicePaymentCanceled:
        return 'notification_hold_invoice_payment_canceled_title';
      case Action.waitingSellerToPay:
        return 'notification_waiting_seller_to_pay_title';
      case Action.waitingBuyerInvoice:
        return 'notification_waiting_buyer_invoice_title';
      case Action.addInvoice:
        return 'notification_add_invoice_title';
      case Action.buyerTookOrder:
        return 'notification_buyer_took_order_title';
      case Action.rate:
      case Action.rateUser:
        return 'notification_rate_title';
      case Action.rateReceived:
        return 'notification_rate_received_title';
      case Action.dispute:
        return 'notification_dispute_started_title';
      case Action.disputeInitiatedByYou:
        return 'notification_dispute_initiated_by_you_title';
      case Action.disputeInitiatedByPeer:
        return 'notification_dispute_initiated_by_peer_title';
      case Action.paymentFailed:
        return 'notification_payment_failed_title';
      case Action.invoiceUpdated:
        return 'notification_invoice_updated_title';
      case Action.cantDo:
        return 'notification_cant_do_title';
      case Action.canceled:
        return 'notification_order_canceled_title';
      case Action.cooperativeCancelInitiatedByYou:
        return 'notification_cooperative_cancel_initiated_by_you_title';
      case Action.cooperativeCancelInitiatedByPeer:
        return 'notification_cooperative_cancel_initiated_by_peer_title';
      case Action.cooperativeCancelAccepted:
        return 'notification_cooperative_cancel_accepted_title';
      case Action.sendDm:
        return 'notification_new_message_title';
      default:
        return 'notification_order_update_title';
    }
  }

  /// Maps an action to its corresponding notification message key
  static String getMessageKey(Action action) {
    switch (action) {
      case Action.newOrder:
        return 'notification_new_order_message';
      case Action.takeBuy:
        return 'notification_sell_order_taken_message';
      case Action.takeSell:
        return 'notification_buy_order_taken_message';
      case Action.payInvoice:
        return 'notification_payment_required_message';
      case Action.fiatSent:
        return 'notification_fiat_sent_message';
      case Action.fiatSentOk:
        return 'notification_fiat_sent_ok_message';
      case Action.release:
        return 'notification_release_message';
      case Action.released:
        return 'notification_bitcoin_released_message';
      case Action.buyerInvoiceAccepted:
        return 'notification_buyer_invoice_accepted_message';
      case Action.purchaseCompleted:
        return 'notification_purchase_completed_message';
      case Action.holdInvoicePaymentAccepted:
        return 'notification_hold_invoice_payment_accepted_message';
      case Action.holdInvoicePaymentSettled:
        return 'notification_hold_invoice_payment_settled_message';
      case Action.holdInvoicePaymentCanceled:
        return 'notification_hold_invoice_payment_canceled_message';
      case Action.waitingSellerToPay:
        return 'notification_waiting_seller_to_pay_message';
      case Action.waitingBuyerInvoice:
        return 'notification_waiting_buyer_invoice_message';
      case Action.addInvoice:
        return 'notification_add_invoice_message';
      case Action.buyerTookOrder:
        return 'notification_buyer_took_order_message';
      case Action.rate:
      case Action.rateUser:
        return 'notification_rate_message';
      case Action.rateReceived:
        return 'notification_rate_received_message';
      case Action.dispute:
        return 'notification_dispute_started_message';
      case Action.disputeInitiatedByYou:
        return 'notification_dispute_initiated_by_you_message';
      case Action.disputeInitiatedByPeer:
        return 'notification_dispute_initiated_by_peer_message';
      case Action.paymentFailed:
        return 'notification_payment_failed_message';
      case Action.invoiceUpdated:
        return 'notification_invoice_updated_message';
      case Action.cantDo:
        return 'notification_cant_do_message';
      case Action.canceled:
        return 'notification_order_canceled_message';
      case Action.cooperativeCancelInitiatedByYou:
        return 'notification_cooperative_cancel_initiated_by_you_message';
      case Action.cooperativeCancelInitiatedByPeer:
        return 'notification_cooperative_cancel_initiated_by_peer_message';
      case Action.cooperativeCancelAccepted:
        return 'notification_cooperative_cancel_accepted_message';
      case Action.sendDm:
        return 'notification_new_message_message';
      default:
        return 'notification_order_update_message';
    }
  }
}