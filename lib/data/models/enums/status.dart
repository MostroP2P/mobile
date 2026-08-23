enum Status {
  active('active'),
  canceled('canceled'),
  canceledByAdmin('canceled-by-admin'),
  settledByAdmin('settled-by-admin'),
  completedByAdmin('completed-by-admin'),
  dispute('dispute'),
  expired('expired'),
  fiatSent('fiat-sent'),
  settledHoldInvoice('settled-hold-invoice'),
  pending('pending'),
  success('success'),
  waitingBuyerInvoice('waiting-buyer-invoice'),
  waitingPayment('waiting-payment'),
  waitingTakerBond('waiting-taker-bond'),
  paymentFailed('payment-failed'),
  cooperativelyCanceled('cooperatively-canceled'),
  inProgress('in-progress');

  final String value;

  const Status(this.value);

  static Status fromString(String value) {
    return Status.values.firstWhere(
      (k) => k.value == value,
      orElse: () => throw ArgumentError('Invalid Status: $value'),
    );
  }

  /// Whether this status represents a completed/final state
  /// where the session can be safely deleted during cleanup.
  bool get isTerminal => switch (this) {
        Status.success ||
        Status.canceled ||
        Status.canceledByAdmin ||
        Status.settledByAdmin ||
        Status.completedByAdmin ||
        Status.cooperativelyCanceled ||
        Status.expired ||
        Status.settledHoldInvoice =>
          true,
        _ => false,
      };

  /// Whether an add-invoice on this status asks for the payout of an already
  /// settled order rather than the invoice a take requires.
  ///
  /// Both statuses mean the same thing: the hold invoice is settled and the
  /// only thing left is paying the buyer. [paymentFailed] is where a payout
  /// retry lands, [settledHoldInvoice] is the window between the release and
  /// the payout, where the buyer may want to replace a wrong invoice.
  bool get isPayoutInvoice =>
      this == Status.paymentFailed || this == Status.settledHoldInvoice;

  @override
  String toString() {
    return value;
  }
}
