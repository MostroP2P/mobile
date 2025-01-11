import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';

extension ActionLocalizationX on S {
  String actionLabel(Action action,
      {Map<String, dynamic> placeholders = const {}}) {
    switch (action) {
      case Action.newOrder:
        return newOrder(placeholders['expiration_hours'] ?? 24);
      case Action.payInvoice:
        return payInvoice(placeholders['amount'], placeholders['fiat_code'],
            placeholders['fiat_amount'], placeholders['expiration_seconds']);
      case Action.fiatSentOk:
        if (placeholders['seller_npub']) {
          return fiatSentOkBuyer(placeholders['seller_npub']);
        } else {
          return fiatSentOkSeller(placeholders['buyer_npub']);
        }
      case Action.released:
        return released(placeholders['seller_npub']);
      case Action.canceled:
        return canceled(placeholders['id']);
      case Action.cooperativeCancelInitiatedByYou:
        return cooperativeCancelInitiatedByYou(placeholders['id']);
      case Action.cooperativeCancelInitiatedByPeer:
        return cooperativeCancelInitiatedByPeer(placeholders['id']);
      case Action.disputeInitiatedByYou:
        return disputeInitiatedByYou(
            placeholders['id'], placeholders['user_token']);
      case Action.disputeInitiatedByPeer:
        return disputeInitiatedByPeer(
            placeholders['id'], placeholders['user_token']);
      case Action.cooperativeCancelAccepted:
        return cooperativeCancelAccepted(placeholders['id']);
      case Action.buyerInvoiceAccepted:
        return buyerInvoiceAccepted;
      case Action.purchaseCompleted:
        return purchaseCompleted;
      case Action.holdInvoicePaymentAccepted:
        return holdInvoicePaymentAccepted(
            placeholders['seller_npub'],
            placeholders['id'],
            placeholders['fiat_code'],
            placeholders['fiat_amount'],
            placeholders['payment_method']);
      case Action.holdInvoicePaymentSettled:
        return holdInvoicePaymentSettled(placeholders['buyer_npub']);
      case Action.holdInvoicePaymentCanceled:
        return holdInvoicePaymentCanceled;
      case Action.waitingSellerToPay:
        return waitingSellerToPay(
            placeholders['id'], placeholders['expiration_seconds']);
      case Action.waitingBuyerInvoice:
        return waitingBuyerInvoice((placeholders['expiration_seconds']));
      case Action.addInvoice:
        return addInvoice(placeholders['amount'], placeholders['fiat_code'],
            placeholders['fiat_amount'], placeholders['expiration_seconds']);
      case Action.buyerTookOrder:
        return buyerTookOrder(
            placeholders['buyer_npub'],
            placeholders['fiat_code'],
            placeholders['fiat_amount'],
            placeholders['payment_method']);
      case Action.rate:
        return rate;
      case Action.rateReceived:
        return rateReceived;
      case Action.cantDo:
        return cantDo(placeholders['action']);
      case Action.adminCanceled:
        return this.adminCanceled;
      case Action.adminSettled:
        return this.adminSettled;
      case Action.adminAddSolver:
        return adminAddSolver(placeholders['npub']);
      case Action.adminTookDispute:
        return this.adminTookDispute;
      case Action.isNotYourOrder:
        return isNotYourOrder(placeholders['action']);
      case Action.notAllowedByStatus:
        return notAllowedByStatus(placeholders['action'], placeholders['id'],
            placeholders['order_status']);
      case Action.outOfRangeFiatAmount:
        return outOfRangeFiatAmount(
            placeholders['min_amount'], placeholders['max_amount']);
      case Action.isNotYourDispute:
        return isNotYourDispute;
      case Action.notFound:
        return notFound;
      case Action.incorrectInvoiceAmount:
        return this.incorrectInvoiceAmount;
      case Action.invalidSatsAmount:
        return invalidSatsAmount;
      case Action.outOfRangeSatsAmount:
        return outOfRangeSatsAmount(
            placeholders['min_order_amount'], placeholders['max_order_amount']);
      case Action.paymentFailed:
        return paymentFailed(placeholders['payment_attempts'],
            placeholders['payment_retries_interval']);
      case Action.invoiceUpdated:
        return invoiceUpdated;
    }
  }
}
