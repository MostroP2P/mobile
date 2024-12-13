enum OrderType {
  buy('buy'),
  sell('sell');

  final String value;

  const OrderType(this.value);

  static OrderType fromString(String value) {
    switch (value) {
      case 'buy':
        return OrderType.buy;
      case 'sell':
        return OrderType.sell;
      default:
        throw ArgumentError('Invalid OrderType: $value');
    }
  }
}
