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

  @override
  String toString() {
    return value;
  }
}
