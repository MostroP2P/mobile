import 'package:flutter/material.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as mostro;
import 'package:mostro_mobile/generated/l10n.dart';

/// Utility class to map Mostro actions to notification title and message keys
/// 
/// This class provides exhaustive switch statements that handle all Action enum values.
/// The compiler will enforce completeness, causing a compilation error if new enum values
/// are added without corresponding cases in the switch statements.
class NotificationMessageMapper {
  /// Maps an action to its corresponding notification title key
  static String getTitleKey(mostro.Action action) {
    switch (action) {
      case mostro.Action.newOrder:
        return 'notification_new_order_title';
      case mostro.Action.takeBuy:
      case mostro.Action.takeSell:
        return 'notification_order_taken_title';
      case mostro.Action.payInvoice:
        return 'notification_payment_required_title';
      case mostro.Action.fiatSent:
        return 'notification_fiat_sent_title';
      case mostro.Action.fiatSentOk:
        return 'notification_fiat_sent_ok_title';
      case mostro.Action.release:
        return 'notification_release_title';
      case mostro.Action.released:
        return 'notification_bitcoin_released_title';
      case mostro.Action.buyerInvoiceAccepted:
        return 'notification_buyer_invoice_accepted_title';
      case mostro.Action.purchaseCompleted:
        return 'notification_purchase_completed_title';
      case mostro.Action.holdInvoicePaymentAccepted:
        return 'notification_hold_invoice_payment_accepted_title';
      case mostro.Action.holdInvoicePaymentSettled:
        return 'notification_hold_invoice_payment_settled_title';
      case mostro.Action.holdInvoicePaymentCanceled:
        return 'notification_hold_invoice_payment_canceled_title';
      case mostro.Action.waitingSellerToPay:
        return 'notification_waiting_seller_to_pay_title';
      case mostro.Action.waitingBuyerInvoice:
        return 'notification_waiting_buyer_invoice_title';
      case mostro.Action.addInvoice:
        return 'notification_add_invoice_title';
      case mostro.Action.buyerTookOrder:
        return 'notification_buyer_took_order_title';
      case mostro.Action.rate:
      case mostro.Action.rateUser:
        return 'notification_rate_title';
      case mostro.Action.rateReceived:
        return 'notification_rate_received_title';
      case mostro.Action.dispute:
        return 'notification_dispute_started_title';
      case mostro.Action.disputeInitiatedByYou:
        return 'notification_dispute_initiated_by_you_title';
      case mostro.Action.disputeInitiatedByPeer:
        return 'notification_dispute_initiated_by_peer_title';
      case mostro.Action.paymentFailed:
        return 'notification_payment_failed_title';
      case mostro.Action.invoiceUpdated:
        return 'notification_invoice_updated_title';
      case mostro.Action.cantDo:
        return 'notification_cant_do_title';
      case mostro.Action.canceled:
        return 'notification_order_canceled_title';
      case mostro.Action.cooperativeCancelInitiatedByYou:
        return 'notification_cooperative_cancel_initiated_by_you_title';
      case mostro.Action.cooperativeCancelInitiatedByPeer:
        return 'notification_cooperative_cancel_initiated_by_peer_title';
      case mostro.Action.cooperativeCancelAccepted:
        return 'notification_cooperative_cancel_accepted_title';
      case mostro.Action.sendDm:
        return 'notification_new_message_title';
      case mostro.Action.cancel:
      case mostro.Action.adminCancel:
      case mostro.Action.adminCanceled:
        return 'notification_order_canceled_title';
      case mostro.Action.adminSettle:
      case mostro.Action.adminSettled:
        return 'notification_order_update_title';
      case mostro.Action.adminAddSolver:
      case mostro.Action.adminTakeDispute:
      case mostro.Action.adminTookDispute:
        return 'notification_dispute_started_title';
      case mostro.Action.tradePubkey:
      case mostro.Action.timeoutReversal:
        return 'notification_order_update_title';
    }
  }

  /// Maps an action to its corresponding notification message key with context values
  static String getMessageKeyWithContext(mostro.Action action, Map<String, dynamic>? values) {
    // Handle special cases with context
    if (values != null && action == mostro.Action.addInvoice) {
      if (values.containsKey('fiat_amount') && values.containsKey('failed_at')) {
        return 'notification_add_invoice_after_failure_message';
      }
    }
    // Fall back to normal message key
    return getMessageKey(action);
  }

  /// Maps an action to its corresponding notification message key
  static String getMessageKey(mostro.Action action) {
    switch (action) {
      case mostro.Action.newOrder:
        return 'notification_new_order_message';
      case mostro.Action.takeBuy:
        return 'notification_sell_order_taken_message';
      case mostro.Action.takeSell:
        return 'notification_buy_order_taken_message';
      case mostro.Action.payInvoice:
        return 'notification_payment_required_message';
      case mostro.Action.fiatSent:
        return 'notification_fiat_sent_message';
      case mostro.Action.fiatSentOk:
        return 'notification_fiat_sent_ok_message';
      case mostro.Action.release:
        return 'notification_release_message';
      case mostro.Action.released:
        return 'notification_bitcoin_released_message';
      case mostro.Action.buyerInvoiceAccepted:
        return 'notification_buyer_invoice_accepted_message';
      case mostro.Action.purchaseCompleted:
        return 'notification_purchase_completed_message';
      case mostro.Action.holdInvoicePaymentAccepted:
        return 'notification_hold_invoice_payment_accepted_message';
      case mostro.Action.holdInvoicePaymentSettled:
        return 'holdInvoicePaymentSettled';
      case mostro.Action.holdInvoicePaymentCanceled:
        return 'notification_hold_invoice_payment_canceled_message';
      case mostro.Action.waitingSellerToPay:
        return 'notification_waiting_seller_to_pay_message';
      case mostro.Action.waitingBuyerInvoice:
        return 'notification_waiting_buyer_invoice_message';
      case mostro.Action.addInvoice:
        return 'notification_add_invoice_message';
      case mostro.Action.buyerTookOrder:
        return 'notification_buyer_took_order_message';
      case mostro.Action.rate:
      case mostro.Action.rateUser:
        return 'notification_rate_message';
      case mostro.Action.rateReceived:
        return 'notification_rate_received_message';
      case mostro.Action.dispute:
        return 'notification_dispute_started_message';
      case mostro.Action.disputeInitiatedByYou:
        return 'notification_dispute_initiated_by_you_message';
      case mostro.Action.disputeInitiatedByPeer:
        return 'notification_dispute_initiated_by_peer_message';
      case mostro.Action.paymentFailed:
        return 'notification_payment_failed_message';
      case mostro.Action.invoiceUpdated:
        return 'notification_invoice_updated_message';
      case mostro.Action.cantDo:
        return 'notification_cant_do_message';
      case mostro.Action.canceled:
        return 'notification_order_canceled_message';
      case mostro.Action.cooperativeCancelInitiatedByYou:
        return 'notification_cooperative_cancel_initiated_by_you_message';
      case mostro.Action.cooperativeCancelInitiatedByPeer:
        return 'notification_cooperative_cancel_initiated_by_peer_message';
      case mostro.Action.cooperativeCancelAccepted:
        return 'notification_cooperative_cancel_accepted_message';
      case mostro.Action.sendDm:
        return 'notification_new_message_message';
      case mostro.Action.cancel:
      case mostro.Action.adminCancel:
      case mostro.Action.adminCanceled:
        return 'notification_order_canceled_message';
      case mostro.Action.adminSettle:
      case mostro.Action.adminSettled:
        return 'notification_order_update_message';
      case mostro.Action.adminAddSolver:
      case mostro.Action.adminTakeDispute:
      case mostro.Action.adminTookDispute:
        return 'notification_dispute_started_message';
      case mostro.Action.tradePubkey:
      case mostro.Action.timeoutReversal:
        return 'notification_order_update_message';
    }
  }

  /// Get localized title text directly from Action
  static String getLocalizedTitle(BuildContext context, mostro.Action action) {
    final s = S.of(context)!;
    return _resolveLocalizationKey(s, getTitleKey(action));
  }

  /// Get localized message text directly from Action  
  static String getLocalizedMessage(BuildContext context, mostro.Action action, {Map<String, dynamic>? values}) {
    final s = S.of(context)!;
    final messageKey = getMessageKeyWithContext(action, values);
    
    // Handle special keys that require parameters
    switch (messageKey) {
      case 'holdInvoicePaymentSettled':
        final buyerName = values?['buyer_npub'] ?? '';
        return s.holdInvoicePaymentSettled(buyerName);
      default:
        return _resolveLocalizationKey(s, messageKey);
    }
  }

  /// Helper method to resolve localization keys to actual text
  static String _resolveLocalizationKey(S s, String key) {
    switch (key) {
      case 'notification_new_order_title':
        return s.notification_new_order_title;
      case 'notification_new_order_message':
        return s.notification_new_order_message;
      case 'notification_order_taken_title':
        return s.notification_order_taken_title;
      case 'notification_sell_order_taken_message':
        return s.notification_sell_order_taken_message;
      case 'notification_buy_order_taken_message':
        return s.notification_buy_order_taken_message;
      case 'notification_payment_required_title':
        return s.notification_payment_required_title;
      case 'notification_payment_required_message':
        return s.notification_payment_required_message;
      case 'notification_fiat_sent_title':
        return s.notification_fiat_sent_title;
      case 'notification_fiat_sent_message':
        return s.notification_fiat_sent_message;
      case 'notification_fiat_sent_ok_title':
        return s.notification_fiat_sent_ok_title;
      case 'notification_fiat_sent_ok_message':
        return s.notification_fiat_sent_ok_message;
      case 'notification_release_title':
        return s.notification_release_title;
      case 'notification_release_message':
        return s.notification_release_message;
      case 'notification_bitcoin_released_title':
        return s.notification_bitcoin_released_title;
      case 'notification_bitcoin_released_message':
        return s.notification_bitcoin_released_message;
      case 'notification_buyer_invoice_accepted_title':
        return s.notification_buyer_invoice_accepted_title;
      case 'notification_buyer_invoice_accepted_message':
        return s.notification_buyer_invoice_accepted_message;
      case 'notification_purchase_completed_title':
        return s.notification_purchase_completed_title;
      case 'notification_purchase_completed_message':
        return s.notification_purchase_completed_message;
      case 'notification_hold_invoice_payment_accepted_title':
        return s.notification_hold_invoice_payment_accepted_title;
      case 'notification_hold_invoice_payment_accepted_message':
        return s.notification_hold_invoice_payment_accepted_message;
      case 'notification_hold_invoice_payment_settled_title':
        return s.notification_hold_invoice_payment_settled_title;
      case 'notification_hold_invoice_payment_settled_message':
        return s.notification_hold_invoice_payment_settled_message;
      case 'notification_hold_invoice_payment_canceled_title':
        return s.notification_hold_invoice_payment_canceled_title;
      case 'notification_hold_invoice_payment_canceled_message':
        return s.notification_hold_invoice_payment_canceled_message;
      case 'notification_waiting_seller_to_pay_title':
        return s.notification_waiting_seller_to_pay_title;
      case 'notification_waiting_seller_to_pay_message':
        return s.notification_waiting_seller_to_pay_message;
      case 'notification_waiting_buyer_invoice_title':
        return s.notification_waiting_buyer_invoice_title;
      case 'notification_waiting_buyer_invoice_message':
        return s.notification_waiting_buyer_invoice_message;
      case 'notification_add_invoice_title':
        return s.notification_add_invoice_title;
      case 'notification_add_invoice_message':
        return s.notification_add_invoice_message;
      case 'notification_buyer_took_order_title':
        return s.notification_buyer_took_order_title;
      case 'notification_buyer_took_order_message':
        return s.notification_buyer_took_order_message;
      case 'notification_rate_title':
        return s.notification_rate_title;
      case 'notification_rate_message':
        return s.notification_rate_message;
      case 'notification_rate_received_title':
        return s.notification_rate_received_title;
      case 'notification_rate_received_message':
        return s.notification_rate_received_message;
      case 'notification_dispute_started_title':
        return s.notification_dispute_started_title;
      case 'notification_dispute_started_message':
        return s.notification_dispute_started_message;
      case 'notification_dispute_initiated_by_you_title':
        return s.notification_dispute_initiated_by_you_title;
      case 'notification_dispute_initiated_by_you_message':
        return s.notification_dispute_initiated_by_you_message;
      case 'notification_dispute_initiated_by_peer_title':
        return s.notification_dispute_initiated_by_peer_title;
      case 'notification_dispute_initiated_by_peer_message':
        return s.notification_dispute_initiated_by_peer_message;
      case 'notification_payment_failed_title':
        return s.notification_payment_failed_title;
      case 'notification_payment_failed_message':
        return s.notification_payment_failed_message;
      case 'notification_invoice_updated_title':
        return s.notification_invoice_updated_title;
      case 'notification_invoice_updated_message':
        return s.notification_invoice_updated_message;
      case 'notification_cant_do_title':
        return s.notification_cant_do_title;
      case 'notification_cant_do_message':
        return s.notification_cant_do_message;
      case 'notification_order_canceled_title':
        return s.notification_order_canceled_title;
      case 'notification_order_canceled_message':
        return s.notification_order_canceled_message;
      case 'notification_cooperative_cancel_initiated_by_you_title':
        return s.notification_cooperative_cancel_initiated_by_you_title;
      case 'notification_cooperative_cancel_initiated_by_you_message':
        return s.notification_cooperative_cancel_initiated_by_you_message;
      case 'notification_cooperative_cancel_initiated_by_peer_title':
        return s.notification_cooperative_cancel_initiated_by_peer_title;
      case 'notification_cooperative_cancel_initiated_by_peer_message':
        return s.notification_cooperative_cancel_initiated_by_peer_message;
      case 'notification_cooperative_cancel_accepted_title':
        return s.notification_cooperative_cancel_accepted_title;
      case 'notification_cooperative_cancel_accepted_message':
        return s.notification_cooperative_cancel_accepted_message;
      case 'notification_new_message_title':
        return s.notification_new_message_title;
      case 'notification_new_message_message':
        return s.notification_new_message_message;
      case 'notification_order_update_title':
        return s.notification_order_update_title;
      case 'notification_order_update_message':
        return s.notification_order_update_message;
      case 'notification_add_invoice_after_failure_message':
        return s.notification_add_invoice_after_failure_message;
      default:
        return key; // Fallback to key if not found
    }
  }
  
  /// Get localized title using S instance directly (for background notifications)
  static String getLocalizedTitleWithInstance(S localizations, mostro.Action action) {
    final titleKey = getTitleKey(action);
    return _resolveLocalizationKey(localizations, titleKey);
  }
  
  /// Get localized message using S instance directly (for background notifications)
  static String getLocalizedMessageWithInstance(S localizations, mostro.Action action, {Map<String, dynamic>? values}) {
    final messageKey = getMessageKeyWithContext(action, values);
    
    // Handle special keys that require parameters
    switch (messageKey) {
      case 'holdInvoicePaymentSettled':
        final buyerName = values?['buyer_npub'] ?? '';
        return localizations.holdInvoicePaymentSettled(buyerName);
      default:
        return _resolveLocalizationKey(localizations, messageKey);
    }
  }
}