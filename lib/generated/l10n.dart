import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'l10n_en.dart';
import 'l10n_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of S
/// returned by `S.of(context)`.
///
/// Applications need to include `S.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: S.localizationsDelegates,
///   supportedLocales: S.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the S.supportedLocales
/// property.
abstract class S {
  S(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static S? of(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('it')
  ];

  /// No description provided for @newOrder.
  ///
  /// In en, this message translates to:
  /// **'Your offer has been published! Please wait until another user picks your order. It will be available for {expiration_hours} hours. You can cancel this order before another user picks it up by executing: cancel.'**
  String newOrder(Object expiration_hours);

  /// No description provided for @canceled.
  ///
  /// In en, this message translates to:
  /// **'You have canceled the order ID: {id}.'**
  String canceled(Object id);

  /// No description provided for @payInvoice.
  ///
  /// In en, this message translates to:
  /// **'Please pay this hold invoice of {amount} Sats for {fiat_code} {fiat_amount} to start the operation. If you do not pay it within {expiration_seconds}, the trade will be canceled.'**
  String payInvoice(Object amount, Object expiration_seconds, Object fiat_amount, Object fiat_code);

  /// No description provided for @addInvoice.
  ///
  /// In en, this message translates to:
  /// **'Please send me an invoice for {amount} satoshis equivalent to {fiat_code} {fiat_amount}. This is where I will send the funds upon trade completion. If you don\'t provide the invoice within {expiration_seconds}, the trade will be canceled.'**
  String addInvoice(Object amount, Object expiration_seconds, Object fiat_amount, Object fiat_code);

  /// No description provided for @waitingSellerToPay.
  ///
  /// In en, this message translates to:
  /// **'Please wait. I’ve sent a payment request to the seller to send the Sats for the order ID {id}. If the seller doesn’t complete the payment within {expiration_seconds}, the trade will be canceled.'**
  String waitingSellerToPay(Object expiration_seconds, Object id);

  /// No description provided for @waitingBuyerInvoice.
  ///
  /// In en, this message translates to:
  /// **'Payment received! Your Sats are now \'held\' in your wallet. I’ve requested the buyer to provide an invoice. If they don’t do so within {expiration_seconds}, your Sats will return to your wallet, and the trade will be canceled.'**
  String waitingBuyerInvoice(Object expiration_seconds);

  /// No description provided for @buyerInvoiceAccepted.
  ///
  /// In en, this message translates to:
  /// **'The invoice has been successfully saved.'**
  String get buyerInvoiceAccepted;

  /// No description provided for @holdInvoicePaymentAccepted.
  ///
  /// In en, this message translates to:
  /// **'Contact the seller at {seller_npub} to arrange how to send {fiat_code} {fiat_amount} using {payment_method}. Once you send the fiat money, please notify me with fiat-sent.'**
  String holdInvoicePaymentAccepted(Object fiat_amount, Object fiat_code, Object payment_method, Object seller_npub);

  /// No description provided for @buyerTookOrder.
  ///
  /// In en, this message translates to:
  /// **'Contact the buyer at {buyer_npub} to inform them how to send {fiat_code} {fiat_amount} through {payment_method}. You’ll be notified when the buyer confirms the fiat payment. Afterward, verify if it has arrived. If the buyer does not respond, you can initiate a cancellation or a dispute. Remember, an administrator will NEVER contact you to resolve your order unless you open a dispute first.'**
  String buyerTookOrder(Object buyer_npub, Object fiat_amount, Object fiat_code, Object payment_method);

  /// No description provided for @fiatSentOkBuyer.
  ///
  /// In en, this message translates to:
  /// **'I have informed {seller_npub} that you sent the fiat money. If the seller confirms receipt, they will release the funds. If they refuse, you can open a dispute.'**
  String fiatSentOkBuyer(Object seller_npub);

  /// No description provided for @fiatSentOkSeller.
  ///
  /// In en, this message translates to:
  /// **'{buyer_npub} has informed you that they sent the fiat money. Once you confirm receipt, please release the funds. After releasing, the money will go to the buyer and there will be no turning back, so only proceed if you are sure. If you want to release the Sats to the buyer, send me release-order-message.'**
  String fiatSentOkSeller(Object buyer_npub);

  /// No description provided for @released.
  ///
  /// In en, this message translates to:
  /// **'{seller_npub} has released the Sats! Expect your invoice to be paid shortly. Ensure your wallet is online to receive via Lightning Network.'**
  String released(Object seller_npub);

  /// No description provided for @purchaseCompleted.
  ///
  /// In en, this message translates to:
  /// **'Your purchase of Bitcoin has been completed successfully. I have paid your invoice; enjoy sound money!'**
  String get purchaseCompleted;

  /// No description provided for @holdInvoicePaymentSettled.
  ///
  /// In en, this message translates to:
  /// **'Your Sats sale has been completed after confirming the payment from {buyer_npub}.'**
  String holdInvoicePaymentSettled(Object buyer_npub);

  /// No description provided for @rate.
  ///
  /// In en, this message translates to:
  /// **'Please rate your counterparty'**
  String get rate;

  /// No description provided for @rateReceived.
  ///
  /// In en, this message translates to:
  /// **'Rating successfully saved!'**
  String get rateReceived;

  /// No description provided for @cooperativeCancelInitiatedByYou.
  ///
  /// In en, this message translates to:
  /// **'You have initiated the cancellation of the order ID: {id}. Your counterparty must agree. If they do not respond, you can open a dispute. Note that no administrator will contact you regarding this cancellation unless you open a dispute first.'**
  String cooperativeCancelInitiatedByYou(Object id);

  /// No description provided for @cooperativeCancelInitiatedByPeer.
  ///
  /// In en, this message translates to:
  /// **'Your counterparty wants to cancel order ID: {id}. If you agree, please send me cancel-order-message. Note that no administrator will contact you regarding this cancellation unless you open a dispute first.'**
  String cooperativeCancelInitiatedByPeer(Object id);

  /// No description provided for @cooperativeCancelAccepted.
  ///
  /// In en, this message translates to:
  /// **'Order {id} has been successfully canceled!'**
  String cooperativeCancelAccepted(Object id);

  /// No description provided for @disputeInitiatedByYou.
  ///
  /// In en, this message translates to:
  /// **'You have initiated a dispute for order Id: {id}. A solver will be assigned soon. Once assigned, I will share their npub with you, and only they will be able to assist you. Your dispute token is: {user_token}.'**
  String disputeInitiatedByYou(Object id, Object user_token);

  /// No description provided for @disputeInitiatedByPeer.
  ///
  /// In en, this message translates to:
  /// **'Your counterparty has initiated a dispute for order Id: {id}. A solver will be assigned soon. Once assigned, I will share their npub with you, and only they will be able to assist you. Your dispute token is: {user_token}.'**
  String disputeInitiatedByPeer(Object id, Object user_token);

  /// No description provided for @adminTookDisputeAdmin.
  ///
  /// In en, this message translates to:
  /// **'Here are the details of the dispute order you have taken: {details}. You need to determine which user is correct and decide whether to cancel or complete the order. Please note that your decision will be final and cannot be reversed.'**
  String adminTookDisputeAdmin(Object details);

  /// No description provided for @adminTookDisputeUsers.
  ///
  /// In en, this message translates to:
  /// **'The solver {admin_npub} will handle your dispute. You can contact them directly, but if they reach out to you first, make sure to ask them for your dispute token.'**
  String adminTookDisputeUsers(Object admin_npub);

  /// No description provided for @adminCanceledAdmin.
  ///
  /// In en, this message translates to:
  /// **'You have canceled the order ID: {id}.'**
  String adminCanceledAdmin(Object id);

  /// No description provided for @adminCanceledUsers.
  ///
  /// In en, this message translates to:
  /// **'Admin has canceled the order ID: {id}.'**
  String adminCanceledUsers(Object id);

  /// No description provided for @adminSettledAdmin.
  ///
  /// In en, this message translates to:
  /// **'You have completed the order ID: {id}.'**
  String adminSettledAdmin(Object id);

  /// No description provided for @adminSettledUsers.
  ///
  /// In en, this message translates to:
  /// **'Admin has completed the order ID: {id}.'**
  String adminSettledUsers(Object id);

  /// No description provided for @paymentFailed.
  ///
  /// In en, this message translates to:
  /// **'I couldn’t send the Sats. I will try {payment_attempts} more times in {payment_retries_interval} minutes. Please ensure your node or wallet is online.'**
  String paymentFailed(Object payment_attempts, Object payment_retries_interval);

  /// No description provided for @invoiceUpdated.
  ///
  /// In en, this message translates to:
  /// **'The invoice has been successfully updated!'**
  String get invoiceUpdated;

  /// No description provided for @holdInvoicePaymentCanceled.
  ///
  /// In en, this message translates to:
  /// **'The invoice was canceled; your Sats are available in your wallet again.'**
  String get holdInvoicePaymentCanceled;

  /// No description provided for @cantDo.
  ///
  /// In en, this message translates to:
  /// **'You are not allowed to {action} for this order!'**
  String cantDo(Object action);

  /// No description provided for @adminAddSolver.
  ///
  /// In en, this message translates to:
  /// **'You have successfully added the solver {npub}.'**
  String adminAddSolver(Object npub);

  /// No description provided for @invalidSignature.
  ///
  /// In en, this message translates to:
  /// **'The action cannot be completed because the signature is invalid.'**
  String get invalidSignature;

  /// No description provided for @invalidTradeIndex.
  ///
  /// In en, this message translates to:
  /// **'The provided trade index is invalid. Please ensure your client is synchronized and try again.'**
  String get invalidTradeIndex;

  /// No description provided for @invalidAmount.
  ///
  /// In en, this message translates to:
  /// **'The provided amount is invalid. Please verify it and try again.'**
  String get invalidAmount;

  /// No description provided for @invalidInvoice.
  ///
  /// In en, this message translates to:
  /// **'The provided Lightning invoice is invalid. Please check the invoice details and try again.'**
  String get invalidInvoice;

  /// No description provided for @invalidPaymentRequest.
  ///
  /// In en, this message translates to:
  /// **'The payment request is invalid or cannot be processed.'**
  String get invalidPaymentRequest;

  /// No description provided for @invalidPeer.
  ///
  /// In en, this message translates to:
  /// **'You are not authorized to perform this action.'**
  String get invalidPeer;

  /// No description provided for @invalidRating.
  ///
  /// In en, this message translates to:
  /// **'The rating value is invalid or out of range.'**
  String get invalidRating;

  /// No description provided for @invalidTextMessage.
  ///
  /// In en, this message translates to:
  /// **'The text message is invalid or contains prohibited content.'**
  String get invalidTextMessage;

  /// No description provided for @invalidOrderKind.
  ///
  /// In en, this message translates to:
  /// **'The order kind is invalid.'**
  String get invalidOrderKind;

  /// No description provided for @invalidOrderStatus.
  ///
  /// In en, this message translates to:
  /// **'The action cannot be completed due to the current order status.'**
  String get invalidOrderStatus;

  /// No description provided for @invalidPubkey.
  ///
  /// In en, this message translates to:
  /// **'The action cannot be completed because the public key is invalid.'**
  String get invalidPubkey;

  /// No description provided for @invalidParameters.
  ///
  /// In en, this message translates to:
  /// **'The action cannot be completed due to invalid parameters. Please review the provided values and try again.'**
  String get invalidParameters;

  /// No description provided for @orderAlreadyCanceled.
  ///
  /// In en, this message translates to:
  /// **'The action cannot be completed because the order has already been canceled.'**
  String get orderAlreadyCanceled;

  /// No description provided for @cantCreateUser.
  ///
  /// In en, this message translates to:
  /// **'The action cannot be completed because the user could not be created.'**
  String get cantCreateUser;

  /// No description provided for @isNotYourOrder.
  ///
  /// In en, this message translates to:
  /// **'This order does not belong to you.'**
  String get isNotYourOrder;

  /// No description provided for @notAllowedByStatus.
  ///
  /// In en, this message translates to:
  /// **'The action cannot be completed because order Id {id} status is {order_status}.'**
  String notAllowedByStatus(Object id, Object order_status);

  /// No description provided for @outOfRangeFiatAmount.
  ///
  /// In en, this message translates to:
  /// **'The requested fiat amount is outside the acceptable range ({min_amount}–{max_amount}).'**
  String outOfRangeFiatAmount(Object max_amount, Object min_amount);

  /// No description provided for @outOfRangeSatsAmount.
  ///
  /// In en, this message translates to:
  /// **'The allowed Sats amount for this Mostro is between min {min_order_amount} and max {max_order_amount}. Please enter an amount within this range.'**
  String outOfRangeSatsAmount(Object max_order_amount, Object min_order_amount);

  /// No description provided for @isNotYourDispute.
  ///
  /// In en, this message translates to:
  /// **'This dispute is not assigned to you.'**
  String get isNotYourDispute;

  /// No description provided for @disputeCreationError.
  ///
  /// In en, this message translates to:
  /// **'A dispute cannot be created for this order.'**
  String get disputeCreationError;

  /// No description provided for @notFound.
  ///
  /// In en, this message translates to:
  /// **'The requested dispute could not be found.'**
  String get notFound;

  /// No description provided for @invalidDisputeStatus.
  ///
  /// In en, this message translates to:
  /// **'The dispute status is invalid.'**
  String get invalidDisputeStatus;

  /// No description provided for @invalidAction.
  ///
  /// In en, this message translates to:
  /// **'The requested action is invalid.'**
  String get invalidAction;

  /// No description provided for @pendingOrderExists.
  ///
  /// In en, this message translates to:
  /// **'A pending order already exists.'**
  String get pendingOrderExists;
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return SEn();
    case 'it': return SIt();
  }

  throw FlutterError(
    'S.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
