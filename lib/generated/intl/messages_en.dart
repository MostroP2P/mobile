// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a en locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'en';

  static String m0(amount, fiat_code, fiat_amount, expiration_seconds) =>
      "Please send me an invoice for ${amount} satoshis equivalent to ${fiat_code} ${fiat_amount}. This is where I\'ll send the funds upon completion of the trade. If you don\'t provide the invoice within ${expiration_seconds} this trade will be cancelled.";

  static String m1(npub) => "You have successfully added the solver ${npub}.";

  static String m2(id) => "You have cancelled the order ID: ${id}!";

  static String m3(id) => "Admin has cancelled the order ID: ${id}!";

  static String m4(id) => "You have completed the order ID: ${id}!";

  static String m5(id) => "Admin has completed the order ID: ${id}!";

  static String m6(details) =>
      "Here are the details of the dispute order you have taken: ${details}. You need to determine which user is correct and decide whether to cancel or complete the order. Please note that your decision will be final and cannot be reversed.";

  static String m7(admin_npub) =>
      "The solver ${admin_npub} will handle your dispute. You can contact them directly, but if they reach out to you first, make sure to ask them for your dispute token.";

  static String m8(buyer_npub, fiat_code, fiat_amount, payment_method) =>
      "Get in touch with the buyer, this is their npub ${buyer_npub} to inform them how to send you ${fiat_code} ${fiat_amount} through ${payment_method}. I will notify you once the buyer indicates the fiat money has been sent. Afterward, you should verify if it has arrived. If the buyer does not respond, you can initiate a cancellation or a dispute. Remember, an administrator will NEVER contact you to resolve your order unless you open a dispute first.";

  static String m9(id) => "You have cancelled the order ID: ${id}!";

  static String m10(action) =>
      "You are not allowed to ${action} for this order!";

  static String m11(id) => "Order ${id} has been successfully cancelled!";

  static String m12(id) =>
      "Your counterparty wants to cancel order ID: ${id}. Note that no administrator will contact you regarding this cancellation unless you open a dispute first. If you agree on such cancellation, please send me cancel-order-message.";

  static String m13(id) =>
      "You have initiated the cancellation of the order ID: ${id}. Your counterparty must agree to the cancellation too. If they do not respond, you can open a dispute. Note that no administrator will contact you regarding this cancellation unless you open a dispute first.";

  static String m14(id, user_token) =>
      "Your counterparty has initiated a dispute for order Id: ${id}. A solver will be assigned to your dispute soon. Once assigned, I will share their npub with you, and only they will be able to assist you. You may contact the solver directly, but if they reach out first, please ask them to provide the token for your dispute. Your dispute token is: ${user_token}.";

  static String m15(id, user_token) =>
      "You have initiated a dispute for order Id: ${id}. A solver will be assigned to your dispute soon. Once assigned, I will share their npub with you, and only they will be able to assist you. You may contact the solver directly, but if they reach out first, please ask them to provide the token for your dispute. Your dispute token is: ${user_token}.";

  static String m16(seller_npub) =>
      "I have informed ${seller_npub} that you have sent the fiat money. When the seller confirms they have received your fiat money, they should release the funds. If they refuse, you can open a dispute.";

  static String m17(buyer_npub) =>
      "${buyer_npub} has informed that they have sent you the fiat money. Once you confirm receipt, please release the funds. After releasing, the money will go to the buyer and there will be no turning back, so only proceed if you are sure. If you want to release the Sats to the buyer, tap the release button.";

  static String m18(seller_npub, id, fiat_code, fiat_amount, payment_method) =>
      "Get in touch with the seller, this is their npub ${seller_npub} to get the details on how to send the fiat money for the order ${id}, you must send ${fiat_code} ${fiat_amount} using ${payment_method}. Once you send the fiat money, please let me know with fiat-sent.";

  static String m19(buyer_npub) =>
      "Your Sats sale has been completed after confirming the payment from ${buyer_npub}.";

  static String m20(amount) =>
      "The amount stated in the invoice is incorrect. Please send an invoice with an amount of ${amount} satoshis, an invoice without an amount, or a lightning address.";

  static String m21(action) =>
      "You did not create this order and are not authorized to ${action} it.";

  static String m22(expiration_hours) =>
      "Your offer has been published! Please wait until another user picks your order. It will be available for ${expiration_hours} hours. You can cancel this order before another user picks it up by executing: cancel.";

  static String m23(action, id, order_status) =>
      "You are not allowed to ${action} because order Id ${id} status is ${order_status}.";

  static String m24(min_amount, max_amount) =>
      "The requested amount is incorrect and may be outside the acceptable range. The minimum is ${min_amount} and the maximum is ${max_amount}.";

  static String m25(min_order_amount, max_order_amount) =>
      "The allowed Sats amount for this Mostro is between min ${min_order_amount} and max ${max_order_amount}. Please enter an amount within this range.";

  static String m26(amount, fiat_code, fiat_amount, expiration_seconds) =>
      "Please pay this hold invoice of ${amount} Sats for ${fiat_code} ${fiat_amount} to start the operation. If you do not pay it within ${expiration_seconds} the trade will be cancelled.";

  static String m27(payment_attempts, payment_retries_interval) =>
      "I tried to send you the Sats but the payment of your invoice failed. I will try ${payment_attempts} more times in ${payment_retries_interval} minutes window. Please ensure your node/wallet is online.";

  static String m28(seller_npub) =>
      "${seller_npub} has already released the Sats! Expect your invoice to be paid any time. Remember your wallet needs to be online to receive through the Lightning Network.";

  static String m29(expiration_seconds) =>
      "Payment received! Your Sats are now \'held\' in your own wallet. Please wait a bit. I\'ve requested the buyer to provide an invoice. Once they do, I\'ll connect you both. If they do not do so within ${expiration_seconds} your Sats will be available in your wallet again and the trade will be cancelled.";

  static String m30(id, expiration_seconds) =>
      "Please wait a bit. I\'ve sent a payment request to the seller to send the Sats for the order ID ${id}. Once the payment is made, I\'ll connect you both. If the seller doesn\'t complete the payment within ${expiration_seconds} minutes the trade will be cancelled.";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
        "addInvoice": m0,
        "adminAddSolver": m1,
        "adminCanceledAdmin": m2,
        "adminCanceledUsers": m3,
        "adminSettledAdmin": m4,
        "adminSettledUsers": m5,
        "adminTookDisputeAdmin": m6,
        "adminTookDisputeUsers": m7,
        "buyerInvoiceAccepted": MessageLookupByLibrary.simpleMessage(
            "Invoice has been successfully saved!"),
        "buyerTookOrder": m8,
        "canceled": m9,
        "cantDo": m10,
        "cooperativeCancelAccepted": m11,
        "cooperativeCancelInitiatedByPeer": m12,
        "cooperativeCancelInitiatedByYou": m13,
        "disputeInitiatedByPeer": m14,
        "disputeInitiatedByYou": m15,
        "fiatSentOkBuyer": m16,
        "fiatSentOkSeller": m17,
        "holdInvoicePaymentAccepted": m18,
        "holdInvoicePaymentCanceled": MessageLookupByLibrary.simpleMessage(
            "The invoice was cancelled; your Sats will be available in your wallet again."),
        "holdInvoicePaymentSettled": m19,
        "incorrectInvoiceAmountBuyerAddInvoice": m20,
        "incorrectInvoiceAmountBuyerNewOrder": MessageLookupByLibrary.simpleMessage(
            "An invoice with non-zero amount was received for the new order. Please send an invoice with a zero amount or no invoice at all."),
        "invalidSatsAmount": MessageLookupByLibrary.simpleMessage(
            "The specified Sats amount is invalid."),
        "invoiceUpdated": MessageLookupByLibrary.simpleMessage(
            "Invoice has been successfully updated!"),
        "isNotYourDispute": MessageLookupByLibrary.simpleMessage(
            "This dispute was not assigned to you!"),
        "isNotYourOrder": m21,
        "newOrder": m22,
        "notAllowedByStatus": m23,
        "notFound": MessageLookupByLibrary.simpleMessage("Dispute not found."),
        "outOfRangeFiatAmount": m24,
        "outOfRangeSatsAmount": m25,
        "payInvoice": m26,
        "paymentFailed": m27,
        "purchaseCompleted": MessageLookupByLibrary.simpleMessage(
            "Your satoshis purchase has been completed successfully. I have paid your invoice, enjoy sound money!"),
        "rate": MessageLookupByLibrary.simpleMessage(
            "Please rate your counterparty"),
        "rateReceived":
            MessageLookupByLibrary.simpleMessage("Rating successfully saved!"),
        "released": m28,
        "waitingBuyerInvoice": m29,
        "waitingSellerToPay": m30
      };
}
