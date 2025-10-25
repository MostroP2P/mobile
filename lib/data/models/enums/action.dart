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
  paymentFailed('payment-failed'),
  invoiceUpdated('invoice-updated'),
  sendDm('send-dm'),
  restoreSession('restore-session'),
  tradePubkey('trade-pubkey');

  final String value;

  const Action(this.value);

  /// Converts a string value to its corresponding Action enum value.
  ///
  /// Throws an ArgumentError if the string doesn't match any Action value.
  static final _valueMap = {
    for (var action in Action.values) action.value: action
  };

  static Action fromString(String value) {
    final action = _valueMap[value];
    if (action == null) {
      throw ArgumentError('Invalid Action: $value');
    }
    return action;
  }

  @override
  String toString() {
    return value;
  }
}
