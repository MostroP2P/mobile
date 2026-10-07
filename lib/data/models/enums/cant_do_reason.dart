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
  invalidFiatCurrency('invalid_fiat_currency'),
  pendingOrderExists('pending_order_exists'),
  tooManyRequests('too_many_requests'),
  maintenanceMode('maintenance_mode'),
  reputationIdentityRequired('reputation_identity_required'),
  notEligibleForReputationExport('not_eligible_for_reputation_export'),
  reputationBoundToOtherIdentity('reputation_bound_to_other_identity'),
  invalidReputationRebind('invalid_reputation_rebind'),
  invalidReputationAttestation('invalid_reputation_attestation'),
  untrustedReputationIssuer('untrusted_reputation_issuer'),
  expiredReputationAttestation('expired_reputation_attestation'),
  reputationIdentityMismatch('reputation_identity_mismatch'),
  reputationAlreadyImported('reputation_already_imported'),
  invalidPayload('invalid_payload'),

  /// A reason this build does not know yet. Newer daemons add reasons; a
  /// client that threw on them would drop the whole message instead of
  /// showing that the action was refused.
  unknown('unknown');

  final String value;

  const CantDoReason(this.value);

  static final _valueMap = {
    for (var cantDo in CantDoReason.values) cantDo.value: cantDo
  };

  static CantDoReason fromString(String value) =>
      _valueMap[value] ?? CantDoReason.unknown;

  @override
  String toString() {
    return value;
  }
}
