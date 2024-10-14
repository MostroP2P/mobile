// lib/data/models/order_model.dart

class OrderModel {
  final String id;
  final String kind; // 'sell' or 'buy'
  final String status;
  final int amount; // in sats
  final String fiatCode;
  final double fiatAmount;
  final String? minAmount; // for range orders
  final String? maxAmount; // for range orders
  final String paymentMethod;
  final double premium;
  final String createdAt;
  final String pubkey;

  OrderModel({
    required this.id,
    required this.kind,
    required this.status,
    required this.amount,
    required this.fiatCode,
    required this.fiatAmount,
    this.minAmount,
    this.maxAmount,
    required this.paymentMethod,
    required this.premium,
    required this.createdAt,
    required this.pubkey,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'],
      kind: json['kind'],
      status: json['status'],
      amount: json['amount'],
      fiatCode: json['fiat_code'],
      fiatAmount: json['fiat_amount'],
      minAmount: json['min_amount'],
      maxAmount: json['max_amount'],
      paymentMethod: json['payment_method'],
      premium: json['premium'],
      createdAt: json['created_at'],
      pubkey: json['pubkey'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kind': kind,
      'status': status,
      'amount': amount,
      'fiat_code': fiatCode,
      'fiat_amount': fiatAmount,
      'min_amount': minAmount,
      'max_amount': maxAmount,
      'payment_method': paymentMethod,
      'premium': premium,
      'created_at': createdAt,
      'pubkey': pubkey,
    };
  }
}
