// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class S {
  S();

  static S? _current;

  static S get current {
    assert(_current != null,
        'No instance of S was loaded. Try to initialize the S delegate before accessing S.current.');
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<S> load(Locale locale) {
    final name = (locale.countryCode?.isEmpty ?? false)
        ? locale.languageCode
        : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = S();
      S._current = instance;

      return instance;
    });
  }

  static S of(BuildContext context) {
    final instance = S.maybeOf(context);
    assert(instance != null,
        'No instance of S present in the widget tree. Did you add S.delegate in localizationsDelegates?');
    return instance!;
  }

  static S? maybeOf(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  /// `Your offer has been published! Please wait until another user picks your order. It will be available for {expiration_hours} hours. You can cancel this order before another user picks it up by executing: cancel.`
  String newOrder(Object expiration_hours) {
    return Intl.message(
      'Your offer has been published! Please wait until another user picks your order. It will be available for $expiration_hours hours. You can cancel this order before another user picks it up by executing: cancel.',
      name: 'newOrder',
      desc: '',
      args: [expiration_hours],
    );
  }

  /// `You have cancelled the order ID: {id}!`
  String canceled(Object id) {
    return Intl.message(
      'You have cancelled the order ID: $id!',
      name: 'canceled',
      desc: '',
      args: [id],
    );
  }

  /// `Please pay this hold invoice of {amount} Sats for {fiat_code} {fiat_amount} to start the operation. If you do not pay it within {expiration_seconds} the trade will be cancelled.`
  String payInvoice(Object amount, Object fiat_code, Object fiat_amount,
      Object expiration_seconds) {
    return Intl.message(
      'Please pay this hold invoice of $amount Sats for $fiat_code $fiat_amount to start the operation. If you do not pay it within $expiration_seconds the trade will be cancelled.',
      name: 'payInvoice',
      desc: '',
      args: [amount, fiat_code, fiat_amount, expiration_seconds],
    );
  }

  /// `Please send me an invoice for {amount} satoshis equivalent to {fiat_code} {fiat_amount}. This is where I'll send the funds upon completion of the trade. If you don't provide the invoice within {expiration_seconds} this trade will be cancelled.`
  String addInvoice(Object amount, Object fiat_code, Object fiat_amount,
      Object expiration_seconds) {
    return Intl.message(
      'Please send me an invoice for $amount satoshis equivalent to $fiat_code $fiat_amount. This is where I\'ll send the funds upon completion of the trade. If you don\'t provide the invoice within $expiration_seconds this trade will be cancelled.',
      name: 'addInvoice',
      desc: '',
      args: [amount, fiat_code, fiat_amount, expiration_seconds],
    );
  }

  /// `Please wait a bit. I've sent a payment request to the seller to send the Sats for the order ID {id}. Once the payment is made, I'll connect you both. If the seller doesn't complete the payment within {expiration_seconds} minutes the trade will be cancelled.`
  String waitingSellerToPay(Object id, Object expiration_seconds) {
    return Intl.message(
      'Please wait a bit. I\'ve sent a payment request to the seller to send the Sats for the order ID $id. Once the payment is made, I\'ll connect you both. If the seller doesn\'t complete the payment within $expiration_seconds minutes the trade will be cancelled.',
      name: 'waitingSellerToPay',
      desc: '',
      args: [id, expiration_seconds],
    );
  }

  /// `Payment received! Your Sats are now 'held' in your own wallet. Please wait a bit. I've requested the buyer to provide an invoice. Once they do, I'll connect you both. If they do not do so within {expiration_seconds} your Sats will be available in your wallet again and the trade will be cancelled.`
  String waitingBuyerInvoice(Object expiration_seconds) {
    return Intl.message(
      'Payment received! Your Sats are now \'held\' in your own wallet. Please wait a bit. I\'ve requested the buyer to provide an invoice. Once they do, I\'ll connect you both. If they do not do so within $expiration_seconds your Sats will be available in your wallet again and the trade will be cancelled.',
      name: 'waitingBuyerInvoice',
      desc: '',
      args: [expiration_seconds],
    );
  }

  /// `Invoice has been successfully saved!`
  String get buyerInvoiceAccepted {
    return Intl.message(
      'Invoice has been successfully saved!',
      name: 'buyerInvoiceAccepted',
      desc: '',
      args: [],
    );
  }

  /// `Get in touch with the seller, this is their npub {seller_npub} to get the details on how to send the fiat money for the order {id}, you must send {fiat_code} {fiat_amount} using {payment_method}. Once you send the fiat money, please let me know with fiat-sent.`
  String holdInvoicePaymentAccepted(Object seller_npub, Object id,
      Object fiat_code, Object fiat_amount, Object payment_method) {
    return Intl.message(
      'Get in touch with the seller, this is their npub $seller_npub to get the details on how to send the fiat money for the order $id, you must send $fiat_code $fiat_amount using $payment_method. Once you send the fiat money, please let me know with fiat-sent.',
      name: 'holdInvoicePaymentAccepted',
      desc: '',
      args: [seller_npub, id, fiat_code, fiat_amount, payment_method],
    );
  }

  /// `Get in touch with the buyer, this is their npub {buyer_npub} to inform them how to send you {fiat_code} {fiat_amount} through {payment_method}. I will notify you once the buyer indicates the fiat money has been sent. Afterward, you should verify if it has arrived. If the buyer does not respond, you can initiate a cancellation or a dispute. Remember, an administrator will NEVER contact you to resolve your order unless you open a dispute first.`
  String buyerTookOrder(Object buyer_npub, Object fiat_code, Object fiat_amount,
      Object payment_method) {
    return Intl.message(
      'Get in touch with the buyer, this is their npub $buyer_npub to inform them how to send you $fiat_code $fiat_amount through $payment_method. I will notify you once the buyer indicates the fiat money has been sent. Afterward, you should verify if it has arrived. If the buyer does not respond, you can initiate a cancellation or a dispute. Remember, an administrator will NEVER contact you to resolve your order unless you open a dispute first.',
      name: 'buyerTookOrder',
      desc: '',
      args: [buyer_npub, fiat_code, fiat_amount, payment_method],
    );
  }

  /// `I have informed {seller_npub} that you have sent the fiat money. When the seller confirms they have received your fiat money, they should release the funds. If they refuse, you can open a dispute.`
  String fiatSentOkBuyer(Object seller_npub) {
    return Intl.message(
      'I have informed $seller_npub that you have sent the fiat money. When the seller confirms they have received your fiat money, they should release the funds. If they refuse, you can open a dispute.',
      name: 'fiatSentOkBuyer',
      desc: '',
      args: [seller_npub],
    );
  }

  /// `{buyer_npub} has informed that they have sent you the fiat money. Once you confirm receipt, please release the funds. After releasing, the money will go to the buyer and there will be no turning back, so only proceed if you are sure. If you want to release the Sats to the buyer, send me release-order-message.`
  String fiatSentOkSeller(Object buyer_npub) {
    return Intl.message(
      '$buyer_npub has informed that they have sent you the fiat money. Once you confirm receipt, please release the funds. After releasing, the money will go to the buyer and there will be no turning back, so only proceed if you are sure. If you want to release the Sats to the buyer, send me release-order-message.',
      name: 'fiatSentOkSeller',
      desc: '',
      args: [buyer_npub],
    );
  }

  /// `{seller_npub} has already released the Sats! Expect your invoice to be paid any time. Remember your wallet needs to be online to receive through the Lightning Network.`
  String released(Object seller_npub) {
    return Intl.message(
      '$seller_npub has already released the Sats! Expect your invoice to be paid any time. Remember your wallet needs to be online to receive through the Lightning Network.',
      name: 'released',
      desc: '',
      args: [seller_npub],
    );
  }

  /// `Your satoshis purchase has been completed successfully. I have paid your invoice, enjoy sound money!`
  String get purchaseCompleted {
    return Intl.message(
      'Your satoshis purchase has been completed successfully. I have paid your invoice, enjoy sound money!',
      name: 'purchaseCompleted',
      desc: '',
      args: [],
    );
  }

  /// `Your Sats sale has been completed after confirming the payment from {buyer_npub}.`
  String holdInvoicePaymentSettled(Object buyer_npub) {
    return Intl.message(
      'Your Sats sale has been completed after confirming the payment from $buyer_npub.',
      name: 'holdInvoicePaymentSettled',
      desc: '',
      args: [buyer_npub],
    );
  }

  /// `Please rate your counterparty`
  String get rate {
    return Intl.message(
      'Please rate your counterparty',
      name: 'rate',
      desc: '',
      args: [],
    );
  }

  /// `Rating successfully saved!`
  String get rateReceived {
    return Intl.message(
      'Rating successfully saved!',
      name: 'rateReceived',
      desc: '',
      args: [],
    );
  }

  /// `You have initiated the cancellation of the order ID: {id}. Your counterparty must agree to the cancellation too. If they do not respond, you can open a dispute. Note that no administrator will contact you regarding this cancellation unless you open a dispute first.`
  String cooperativeCancelInitiatedByYou(Object id) {
    return Intl.message(
      'You have initiated the cancellation of the order ID: $id. Your counterparty must agree to the cancellation too. If they do not respond, you can open a dispute. Note that no administrator will contact you regarding this cancellation unless you open a dispute first.',
      name: 'cooperativeCancelInitiatedByYou',
      desc: '',
      args: [id],
    );
  }

  /// `Your counterparty wants to cancel order ID: {id}. Note that no administrator will contact you regarding this cancellation unless you open a dispute first. If you agree on such cancellation, please send me cancel-order-message.`
  String cooperativeCancelInitiatedByPeer(Object id) {
    return Intl.message(
      'Your counterparty wants to cancel order ID: $id. Note that no administrator will contact you regarding this cancellation unless you open a dispute first. If you agree on such cancellation, please send me cancel-order-message.',
      name: 'cooperativeCancelInitiatedByPeer',
      desc: '',
      args: [id],
    );
  }

  /// `Order {id} has been successfully cancelled!`
  String cooperativeCancelAccepted(Object id) {
    return Intl.message(
      'Order $id has been successfully cancelled!',
      name: 'cooperativeCancelAccepted',
      desc: '',
      args: [id],
    );
  }

  /// `You have initiated a dispute for order Id: {id}. A solver will be assigned to your dispute soon. Once assigned, I will share their npub with you, and only they will be able to assist you. You may contact the solver directly, but if they reach out first, please ask them to provide the token for your dispute. Your dispute token is: {user_token}.`
  String disputeInitiatedByYou(Object id, Object user_token) {
    return Intl.message(
      'You have initiated a dispute for order Id: $id. A solver will be assigned to your dispute soon. Once assigned, I will share their npub with you, and only they will be able to assist you. You may contact the solver directly, but if they reach out first, please ask them to provide the token for your dispute. Your dispute token is: $user_token.',
      name: 'disputeInitiatedByYou',
      desc: '',
      args: [id, user_token],
    );
  }

  /// `Your counterparty has initiated a dispute for order Id: {id}. A solver will be assigned to your dispute soon. Once assigned, I will share their npub with you, and only they will be able to assist you. You may contact the solver directly, but if they reach out first, please ask them to provide the token for your dispute. Your dispute token is: {user_token}.`
  String disputeInitiatedByPeer(Object id, Object user_token) {
    return Intl.message(
      'Your counterparty has initiated a dispute for order Id: $id. A solver will be assigned to your dispute soon. Once assigned, I will share their npub with you, and only they will be able to assist you. You may contact the solver directly, but if they reach out first, please ask them to provide the token for your dispute. Your dispute token is: $user_token.',
      name: 'disputeInitiatedByPeer',
      desc: '',
      args: [id, user_token],
    );
  }

  /// `Here are the details of the dispute order you have taken: {details}. You need to determine which user is correct and decide whether to cancel or complete the order. Please note that your decision will be final and cannot be reversed.`
  String adminTookDisputeAdmin(Object details) {
    return Intl.message(
      'Here are the details of the dispute order you have taken: $details. You need to determine which user is correct and decide whether to cancel or complete the order. Please note that your decision will be final and cannot be reversed.',
      name: 'adminTookDisputeAdmin',
      desc: '',
      args: [details],
    );
  }

  /// `The solver {admin_npub} will handle your dispute. You can contact them directly, but if they reach out to you first, make sure to ask them for your dispute token.`
  String adminTookDisputeUsers(Object admin_npub) {
    return Intl.message(
      'The solver $admin_npub will handle your dispute. You can contact them directly, but if they reach out to you first, make sure to ask them for your dispute token.',
      name: 'adminTookDisputeUsers',
      desc: '',
      args: [admin_npub],
    );
  }

  /// `You have cancelled the order ID: {id}!`
  String adminCanceledAdmin(Object id) {
    return Intl.message(
      'You have cancelled the order ID: $id!',
      name: 'adminCanceledAdmin',
      desc: '',
      args: [id],
    );
  }

  /// `Admin has cancelled the order ID: {id}!`
  String adminCanceledUsers(Object id) {
    return Intl.message(
      'Admin has cancelled the order ID: $id!',
      name: 'adminCanceledUsers',
      desc: '',
      args: [id],
    );
  }

  /// `You have completed the order ID: {id}!`
  String adminSettledAdmin(Object id) {
    return Intl.message(
      'You have completed the order ID: $id!',
      name: 'adminSettledAdmin',
      desc: '',
      args: [id],
    );
  }

  /// `Admin has completed the order ID: {id}!`
  String adminSettledUsers(Object id) {
    return Intl.message(
      'Admin has completed the order ID: $id!',
      name: 'adminSettledUsers',
      desc: '',
      args: [id],
    );
  }

  /// `This dispute was not assigned to you!`
  String get isNotYourDispute {
    return Intl.message(
      'This dispute was not assigned to you!',
      name: 'isNotYourDispute',
      desc: '',
      args: [],
    );
  }

  /// `Dispute not found.`
  String get notFound {
    return Intl.message(
      'Dispute not found.',
      name: 'notFound',
      desc: '',
      args: [],
    );
  }

  /// `I tried to send you the Sats but the payment of your invoice failed. I will try {payment_attempts} more times in {payment_retries_interval} minutes window. Please ensure your node/wallet is online.`
  String paymentFailed(
      Object payment_attempts, Object payment_retries_interval) {
    return Intl.message(
      'I tried to send you the Sats but the payment of your invoice failed. I will try $payment_attempts more times in $payment_retries_interval minutes window. Please ensure your node/wallet is online.',
      name: 'paymentFailed',
      desc: '',
      args: [payment_attempts, payment_retries_interval],
    );
  }

  /// `Invoice has been successfully updated!`
  String get invoiceUpdated {
    return Intl.message(
      'Invoice has been successfully updated!',
      name: 'invoiceUpdated',
      desc: '',
      args: [],
    );
  }

  /// `The invoice was cancelled; your Sats will be available in your wallet again.`
  String get holdInvoicePaymentCanceled {
    return Intl.message(
      'The invoice was cancelled; your Sats will be available in your wallet again.',
      name: 'holdInvoicePaymentCanceled',
      desc: '',
      args: [],
    );
  }

  /// `You are not allowed to {action} for this order!`
  String cantDo(Object action) {
    return Intl.message(
      'You are not allowed to $action for this order!',
      name: 'cantDo',
      desc: '',
      args: [action],
    );
  }

  /// `You have successfully added the solver {npub}.`
  String adminAddSolver(Object npub) {
    return Intl.message(
      'You have successfully added the solver $npub.',
      name: 'adminAddSolver',
      desc: '',
      args: [npub],
    );
  }

  /// `You did not create this order and are not authorized to {action} it.`
  String isNotYourOrder(Object action) {
    return Intl.message(
      'You did not create this order and are not authorized to $action it.',
      name: 'isNotYourOrder',
      desc: '',
      args: [action],
    );
  }

  /// `You are not allowed to {action} because order Id {id} status is {order_status}.`
  String notAllowedByStatus(Object action, Object id, Object order_status) {
    return Intl.message(
      'You are not allowed to $action because order Id $id status is $order_status.',
      name: 'notAllowedByStatus',
      desc: '',
      args: [action, id, order_status],
    );
  }

  /// `The requested amount is incorrect and may be outside the acceptable range. The minimum is {min_amount} and the maximum is {max_amount}.`
  String outOfRangeFiatAmount(Object min_amount, Object max_amount) {
    return Intl.message(
      'The requested amount is incorrect and may be outside the acceptable range. The minimum is $min_amount and the maximum is $max_amount.',
      name: 'outOfRangeFiatAmount',
      desc: '',
      args: [min_amount, max_amount],
    );
  }

  /// `An invoice with non-zero amount was received for the new order. Please send an invoice with a zero amount or no invoice at all.`
  String get incorrectInvoiceAmountBuyerNewOrder {
    return Intl.message(
      'An invoice with non-zero amount was received for the new order. Please send an invoice with a zero amount or no invoice at all.',
      name: 'incorrectInvoiceAmountBuyerNewOrder',
      desc: '',
      args: [],
    );
  }

  /// `The amount stated in the invoice is incorrect. Please send an invoice with an amount of {amount} satoshis, an invoice without an amount, or a lightning address.`
  String incorrectInvoiceAmountBuyerAddInvoice(Object amount) {
    return Intl.message(
      'The amount stated in the invoice is incorrect. Please send an invoice with an amount of $amount satoshis, an invoice without an amount, or a lightning address.',
      name: 'incorrectInvoiceAmountBuyerAddInvoice',
      desc: '',
      args: [amount],
    );
  }

  /// `The specified Sats amount is invalid.`
  String get invalidSatsAmount {
    return Intl.message(
      'The specified Sats amount is invalid.',
      name: 'invalidSatsAmount',
      desc: '',
      args: [],
    );
  }

  /// `The allowed Sats amount for this Mostro is between min {min_order_amount} and max {max_order_amount}. Please enter an amount within this range.`
  String outOfRangeSatsAmount(
      Object min_order_amount, Object max_order_amount) {
    return Intl.message(
      'The allowed Sats amount for this Mostro is between min $min_order_amount and max $max_order_amount. Please enter an amount within this range.',
      name: 'outOfRangeSatsAmount',
      desc: '',
      args: [min_order_amount, max_order_amount],
    );
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<S> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'en'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<S> load(Locale locale) => S.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}
