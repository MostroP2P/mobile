import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/payload.dart';

class BondPayoutRequest implements Payload {
  final BondPayoutOrder order;
  final int slashedAt;

  const BondPayoutRequest({
    required this.order,
    required this.slashedAt,
  });

  @override
  String get type => 'bond_payout_request';

  @override
  Map<String, dynamic> toJson() => {
        type: {
          'order': order.toJson(),
          'slashed_at': slashedAt,
        },
      };

  factory BondPayoutRequest.fromJson(Map<String, dynamic> json) {
    final orderJson = json['order'];
    if (orderJson is! Map<String, dynamic>) {
      throw const FormatException(
          'BondPayoutRequest: missing or invalid order field');
    }
    final slashedAt = json['slashed_at'];
    if (slashedAt is! int) {
      throw const FormatException(
          'BondPayoutRequest: missing or invalid slashed_at field');
    }
    return BondPayoutRequest(
      order: BondPayoutOrder.fromJson(orderJson),
      slashedAt: slashedAt,
    );
  }
}

class BondPayoutOrder {
  final String? id;
  final OrderType kind;
  final int amount;
  final String fiatCode;
  final int? minAmount;
  final int? maxAmount;
  final int fiatAmount;
  final String paymentMethod;
  final int premium;

  const BondPayoutOrder({
    this.id,
    required this.kind,
    required this.amount,
    required this.fiatCode,
    this.minAmount,
    this.maxAmount,
    required this.fiatAmount,
    required this.paymentMethod,
    this.premium = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.value,
        'status': null,
        'amount': amount,
        'fiat_code': fiatCode,
        'min_amount': minAmount,
        'max_amount': maxAmount,
        'fiat_amount': fiatAmount,
        'payment_method': paymentMethod,
        'premium': premium,
        'created_at': null,
        'expires_at': null,
      };

  factory BondPayoutOrder.fromJson(Map<String, dynamic> json) {
    int parseInt(String field) {
      final value = json[field];
      if (value == null) {
        throw FormatException('BondPayoutOrder: missing $field');
      }
      if (value is int) return value;
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
      throw FormatException('BondPayoutOrder: invalid $field: $value');
    }

    int? parseOptionalInt(String field) {
      final value = json[field];
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    String parseString(String field) {
      final value = json[field];
      if (value == null) {
        throw FormatException('BondPayoutOrder: missing $field');
      }
      return value.toString();
    }

    return BondPayoutOrder(
      id: json['id']?.toString(),
      kind: OrderType.fromString(parseString('kind')),
      amount: parseInt('amount'),
      fiatCode: parseString('fiat_code'),
      minAmount: parseOptionalInt('min_amount'),
      maxAmount: parseOptionalInt('max_amount'),
      fiatAmount: parseInt('fiat_amount'),
      paymentMethod: parseString('payment_method'),
      premium: parseOptionalInt('premium') ?? 0,
    );
  }
}
