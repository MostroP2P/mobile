enum CantDoReason {
  invalidSignature('invalid_signature'),
  invalidTradeIndex('invalid_trade_index'),
  invalidAmount('invalid_amount'),
  invalidInvoice('invalid_invoice'),
  invalidPaymentRequest('invalid_payment_request'),
  invalidPeer('invalid_peer'),
  invalidRating('invalid_rating'),
  invalidTextMessage('invalid_text_message'),
  invalidOrderKind('invalid_order_kind'),
  invalidOrderStatus('invalid_order_status'),
  invalidPubkey('invalid_pubkey'),
  invalidParameters('invalid_parameters'),
  orderAlreadyCanceled('order_already_canceled'),
  cantCreateUser('cant_create_user'),
  isNotYourOrder('is_not_your_order'),
  notAllowedByStatus('not_allowed_by_status'),
  outOfRangeFiatAmount('out_of_range_fiat_amount'),
  outOfRangeSatsAmount('out_of_range_sats_amount'),
  isNotYourDispute('is_not_your_dispute'),
  disputeCreationError('dispute_creation_error'),
  notFound('not_found'),
  invalidDisputeStatus('invalid_dispute_status'),
  invalidAction('invalid_action'),
  pendingOrderExists('pending_order_exists');

  final String value;

  const CantDoReason(this.value);

  static final _valueMap = {
    for (var cantDo in CantDoReason.values) cantDo.value: cantDo
  };

  static CantDoReason fromString(String value) {
    final cantDo = _valueMap[value];
    if (cantDo == null) {
      throw ArgumentError('Invalid Can\'t Do Reason: $value');
    }
    return cantDo;
  }

  @override
  String toString() {
    return value;
  }
}
