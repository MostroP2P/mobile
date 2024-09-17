class Order {
  final String id;
  final String kind;
  final String status;
  final int amount;
  final String fiatCode;
  final double fiatAmount;
  final String paymentMethod;
  final double premium;
  final DateTime createdAt;

  Order({
    required this.id,
    required this.kind,
    required this.status,
    required this.amount,
    required this.fiatCode,
    required this.fiatAmount,
    required this.paymentMethod,
    required this.premium,
    required this.createdAt,
  });

  factory Order.fromNostrEvent(NostrEvent event) {
    final tags = Map.fromEntries(event.tags.map((t) => MapEntry(t[0], t[1])));
    return Order(
      id: tags['d'] ?? '',
      kind: tags['k'] ?? '',
      status: tags['s'] ?? '',
      amount: int.parse(tags['amt'] ?? '0'),
      fiatCode: tags['f'] ?? '',
      fiatAmount: double.parse(tags['fa'] ?? '0'),
      paymentMethod: tags['pm'] ?? '',
      premium: double.parse(tags['premium'] ?? '0'),
      createdAt: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
    );
  }

  NostrEvent toNostrEvent(String pubkey) {
    return NostrEvent.fromPartialData(
      kind: 38383,
      tags: [
        ['d', id],
        ['k', kind],
        ['f', fiatCode],
        ['s', status],
        ['amt', amount.toString()],
        ['fa', fiatAmount.toString()],
        ['pm', paymentMethod],
        ['premium', premium.toString()],
        ['y', 'mostrop2p'],
        ['z', 'order'],
      ],
      content: '',
    );
  }
}
