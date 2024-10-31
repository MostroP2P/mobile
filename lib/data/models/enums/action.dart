enum Action {
  newOrder('new-order'),
  takeSell('take-sell'),
  takeBuy('take-buy'),
  payInvoice('pay-invoice'),
  fiatSent('fiat-sent'),
  fiatSentOk('fiat-sent-ok'),
  release('release'),
  released('released'),
  cancel('cancel'),
  canceled('canceled'),
  cooperativeCancelInitiatedByYou('cooperative-cancel-initiated-by-you'),
  cooperativeCancelInitiatedByPeer('cooperative-cancel-initiated-by-peer'),
  disputeInitiatedByYou('dispute-initiated-by-you'),
  disputeInitiatedByPeer('dispute-initiated-by-peer'),
  cooperativeCancelAccepted('cooperative-cancel-accepted'),
  buyerInvoiceAccepted('buyer-invoice-accepted'),
  purchaseCompleted('purchase-completed'),
  holdInvoicePaymentAccepted('hold-invoice-payment-accepted'),
  holdInvoicePaymentSettled('hold-invoice-payment-settled'),
  holdInvoicePaymentCanceled('hold-invoice-payment-canceled'),
  waitingSellerToPay('waiting-seller-to-pay'),
  waitingBuyerInvoice('waiting-buyer-invoice'),
  addInvoice('add-invoice'),
  buyerTookOrder('buyer-took-order'),
  rate('rate'),
  rateUser('rate-user'),
  rateReceived('rate-received'),
  cantDo('cant-do'),
  dispute('dispute'),
  adminCancel('admin-cancel'),
  adminCanceled('admin-canceled'),
  adminSettle('admin-settle'),
  adminSettled('admin-settled'),
  adminAddSolver('admin-add-solver'),
  adminTakeDispute('admin-take-dispute'),
  adminTookDispute('admin-took-dispute'),
  isNotYourOrder('is-not-your-order'),
  notAllowedByStatus('not-allowed-by-status'),
  outOfRangeFiatAmount('out-of-range-fiat-amount'),
  isNotYourDispute('is-not-your-dispute'),
  notFound('not-found'),
  incorrectInvoiceAmount('incorrect-invoice-amount'),
  invalidSatsAmount('invalid-sats-amount'),
  outOfRangeSatsAmount('out-of-range-sats-amount'),
  paymentFailed('payment-failed'),
  invoiceUpdated('invoice-updated');

  final String value;

  const Action(this.value);


    static Action fromString(String value) {
    return Action.values.firstWhere(
      (k) => k.value == value,
      orElse: () => throw ArgumentError('Invalid Kind: $value'),
    );
  }

}
