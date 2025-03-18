enum CantDoReason {
  invalidSignature('invalid-signature'),
  invalidTradeIndex('invalid-trade-index'),
  invalidAmount('invalid-amount'),
  invalidInvoice('invalid-invoice'),
  invalidPaymentRequest('invalid-payment-request'),
  invalidPeer('invalid-peer'),
  invalidRating('invalid-rating'),
  invalidTextMessage('invalid-text-message'),
  invalidOrderKind('invalid-order-kind'),
  invalidOrderStatus('invalid-order-status'),
  invalidPubkey('invalid-pubkey'),
  invalidParameters('invalid-parameters'),
  orderAlreadyCanceled('order-already-canceled'),
  cantCreateUser('cant-create-user'),
  isNotYourOrder('is-not-your-order'),
  notAllowedByStatus('not-allowed-by-status'),
  outOfRangeFiatAmount('out-of-range-fiat-amount'),
  outOfRangeSatsAmount('out-of-range-sats-amount'),
  isNotYourDispute('is-not-your-dispute'),
  disputeCreationError('dispute-creation-error'),
  notFound('not-found'),
  invalidDisputeStatus('invalid-dispute-status'),
  invalidAction('invalid-action'),
  pendingOrderExists('pending-order-exists');

  const CantDoReason(this.value);
  final String value;

  static CantDoReason? fromValue(String value) {
    return CantDoReason.values
        .where((e) => e.value == value)
        .fold(null, (_, e) => e); // or firstWhere + catch
  }

  @override
  String toString() {
    return value;
  }
}
