// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SEn extends S {
  SEn([String locale = 'en']) : super(locale);

  @override
  String newOrder(Object expiration_hours) {
    return 'Your offer has been published! Please wait until another user picks your order. It will be available for $expiration_hours hours. You can cancel this order before another user picks it up by executing: cancel.';
  }

  @override
  String canceled(Object id) {
    return 'You have canceled the order ID: $id.';
  }

  @override
  String payInvoice(Object amount, Object expiration_seconds, Object fiat_amount, Object fiat_code) {
    return 'Please pay this hold invoice of $amount Sats for $fiat_code $fiat_amount to start the operation. If you do not pay it within $expiration_seconds, the trade will be canceled.';
  }

  @override
  String addInvoice(Object amount, Object expiration_seconds, Object fiat_amount, Object fiat_code) {
    return 'Please send me an invoice for $amount satoshis equivalent to $fiat_code $fiat_amount. This is where I will send the funds upon trade completion. If you don\'t provide the invoice within $expiration_seconds, the trade will be canceled.';
  }

  @override
  String waitingSellerToPay(Object expiration_seconds, Object id) {
    return 'Please wait. I’ve sent a payment request to the seller to send the Sats for the order ID $id. If the seller doesn’t complete the payment within $expiration_seconds, the trade will be canceled.';
  }

  @override
  String waitingBuyerInvoice(Object expiration_seconds) {
    return 'Payment received! Your Sats are now \'held\' in your wallet. I’ve requested the buyer to provide an invoice. If they don’t do so within $expiration_seconds, your Sats will return to your wallet, and the trade will be canceled.';
  }

  @override
  String get buyerInvoiceAccepted => 'The invoice has been successfully saved.';

  @override
  String holdInvoicePaymentAccepted(Object fiat_amount, Object fiat_code, Object payment_method, Object seller_npub) {
    return 'Contact the seller at $seller_npub to arrange how to send $fiat_code $fiat_amount using $payment_method. Once you send the fiat money, please notify me with fiat-sent.';
  }

  @override
  String buyerTookOrder(Object buyer_npub, Object fiat_amount, Object fiat_code, Object payment_method) {
    return 'Contact the buyer at $buyer_npub to inform them how to send $fiat_code $fiat_amount through $payment_method. You’ll be notified when the buyer confirms the fiat payment. Afterward, verify if it has arrived. If the buyer does not respond, you can initiate a cancellation or a dispute. Remember, an administrator will NEVER contact you to resolve your order unless you open a dispute first.';
  }

  @override
  String fiatSentOkBuyer(Object seller_npub) {
    return 'I have informed $seller_npub that you sent the fiat money. If the seller confirms receipt, they will release the funds. If they refuse, you can open a dispute.';
  }

  @override
  String fiatSentOkSeller(Object buyer_npub) {
    return '$buyer_npub has informed you that they sent the fiat money. Once you confirm receipt, please release the funds. After releasing, the money will go to the buyer and there will be no turning back, so only proceed if you are sure. If you want to release the Sats to the buyer, send me release-order-message.';
  }

  @override
  String released(Object seller_npub) {
    return '$seller_npub has released the Sats! Expect your invoice to be paid shortly. Ensure your wallet is online to receive via Lightning Network.';
  }

  @override
  String get purchaseCompleted => 'Your purchase of Bitcoin has been completed successfully. I have paid your invoice; enjoy sound money!';

  @override
  String holdInvoicePaymentSettled(Object buyer_npub) {
    return 'Your Sats sale has been completed after confirming the payment from $buyer_npub.';
  }

  @override
  String get rate => 'Please rate your counterparty';

  @override
  String get rateReceived => 'Rating successfully saved!';

  @override
  String cooperativeCancelInitiatedByYou(Object id) {
    return 'You have initiated the cancellation of the order ID: $id. Your counterparty must agree. If they do not respond, you can open a dispute. Note that no administrator will contact you regarding this cancellation unless you open a dispute first.';
  }

  @override
  String cooperativeCancelInitiatedByPeer(Object id) {
    return 'Your counterparty wants to cancel order ID: $id. If you agree, please send me cancel-order-message. Note that no administrator will contact you regarding this cancellation unless you open a dispute first.';
  }

  @override
  String cooperativeCancelAccepted(Object id) {
    return 'Order $id has been successfully canceled!';
  }

  @override
  String disputeInitiatedByYou(Object id, Object user_token) {
    return 'You have initiated a dispute for order Id: $id. A solver will be assigned soon. Once assigned, I will share their npub with you, and only they will be able to assist you. Your dispute token is: $user_token.';
  }

  @override
  String disputeInitiatedByPeer(Object id, Object user_token) {
    return 'Your counterparty has initiated a dispute for order Id: $id. A solver will be assigned soon. Once assigned, I will share their npub with you, and only they will be able to assist you. Your dispute token is: $user_token.';
  }

  @override
  String adminTookDisputeAdmin(Object details) {
    return 'Here are the details of the dispute order you have taken: $details. You need to determine which user is correct and decide whether to cancel or complete the order. Please note that your decision will be final and cannot be reversed.';
  }

  @override
  String adminTookDisputeUsers(Object admin_npub) {
    return 'The solver $admin_npub will handle your dispute. You can contact them directly, but if they reach out to you first, make sure to ask them for your dispute token.';
  }

  @override
  String adminCanceledAdmin(Object id) {
    return 'You have canceled the order ID: $id.';
  }

  @override
  String adminCanceledUsers(Object id) {
    return 'Admin has canceled the order ID: $id.';
  }

  @override
  String adminSettledAdmin(Object id) {
    return 'You have completed the order ID: $id.';
  }

  @override
  String adminSettledUsers(Object id) {
    return 'Admin has completed the order ID: $id.';
  }

  @override
  String paymentFailed(Object payment_attempts, Object payment_retries_interval) {
    return 'I couldn’t send the Sats. I will try $payment_attempts more times in $payment_retries_interval minutes. Please ensure your node or wallet is online.';
  }

  @override
  String get invoiceUpdated => 'The invoice has been successfully updated!';

  @override
  String get holdInvoicePaymentCanceled => 'The invoice was canceled; your Sats are available in your wallet again.';

  @override
  String cantDo(Object action) {
    return 'You are not allowed to $action for this order!';
  }

  @override
  String adminAddSolver(Object npub) {
    return 'You have successfully added the solver $npub.';
  }

  @override
  String get invalidSignature => 'The action cannot be completed because the signature is invalid.';

  @override
  String get invalidTradeIndex => 'The provided trade index is invalid. Please ensure your client is synchronized and try again.';

  @override
  String get invalidAmount => 'The provided amount is invalid. Please verify it and try again.';

  @override
  String get invalidInvoice => 'The provided Lightning invoice is invalid. Please check the invoice details and try again.';

  @override
  String get invalidPaymentRequest => 'The payment request is invalid or cannot be processed.';

  @override
  String get invalidPeer => 'You are not authorized to perform this action.';

  @override
  String get invalidRating => 'The rating value is invalid or out of range.';

  @override
  String get invalidTextMessage => 'The text message is invalid or contains prohibited content.';

  @override
  String get invalidOrderKind => 'The order kind is invalid.';

  @override
  String get invalidOrderStatus => 'The action cannot be completed due to the current order status.';

  @override
  String get invalidPubkey => 'The action cannot be completed because the public key is invalid.';

  @override
  String get invalidParameters => 'The action cannot be completed due to invalid parameters. Please review the provided values and try again.';

  @override
  String get orderAlreadyCanceled => 'The action cannot be completed because the order has already been canceled.';

  @override
  String get cantCreateUser => 'The action cannot be completed because the user could not be created.';

  @override
  String get isNotYourOrder => 'This order does not belong to you.';

  @override
  String notAllowedByStatus(Object id, Object order_status) {
    return 'The action cannot be completed because order Id $id status is $order_status.';
  }

  @override
  String outOfRangeFiatAmount(Object max_amount, Object min_amount) {
    return 'The requested fiat amount is outside the acceptable range ($min_amount–$max_amount).';
  }

  @override
  String outOfRangeSatsAmount(Object max_order_amount, Object min_order_amount) {
    return 'The allowed Sats amount for this Mostro is between min $min_order_amount and max $max_order_amount. Please enter an amount within this range.';
  }

  @override
  String get isNotYourDispute => 'This dispute is not assigned to you.';

  @override
  String get disputeCreationError => 'A dispute cannot be created for this order.';

  @override
  String get notFound => 'The requested dispute could not be found.';

  @override
  String get invalidDisputeStatus => 'The dispute status is invalid.';

  @override
  String get invalidAction => 'The requested action is invalid.';

  @override
  String get pendingOrderExists => 'A pending order already exists.';
}
