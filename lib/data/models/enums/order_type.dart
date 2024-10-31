enum OrderType {
  buy('buy'),
  sell('sell');

  final String value;

  const OrderType(this.value);

  static OrderType fromString(String value) {
    return OrderType.values.firstWhere(
      (k) => k.value == value,
      orElse: () => throw ArgumentError('Invalid Kind: $value'),
    );
  }
}
