import 'package:mostro_mobile/data/models/payload.dart';


class OrdersResponse implements Payload {
  final List<OrderDetail> orders;

  OrdersResponse({required this.orders});

  @override
  String get type => 'orders';

  factory OrdersResponse.fromJson(Map<String, dynamic> json) {
    return OrdersResponse(
      orders: (json['orders'] as List<dynamic>?)
              ?.map((o) => OrderDetail.fromJson(o as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'orders': orders.map((o) => o.toJson()).toList(),
      };
}

class OrderDetail {
  final String id;
  final String kind;
  final String status;
  final int amount;
  final String fiatCode;
  final int? minAmount;
  final int? maxAmount;
  final int fiatAmount;
  final String paymentMethod;
  final int premium;
  final String? buyerTradePubkey;
  final String? sellerTradePubkey;
  final int? createdAt;
  final int? expiresAt;

  OrderDetail({
    required this.id,
    required this.kind,
    required this.status,
    required this.amount,
    required this.fiatCode,
    this.minAmount,
    this.maxAmount,
    required this.fiatAmount,
    required this.paymentMethod,
    required this.premium,
    this.buyerTradePubkey,
    this.sellerTradePubkey,
    this.createdAt,
    this.expiresAt,
  });

  factory OrderDetail.fromJson(Map<String, dynamic> json) {
    return OrderDetail(
      id: json['id'] as String,
      kind: json['kind'] as String,
      status: json['status'] as String,
      amount: json['amount'] as int,
      fiatCode: json['fiat_code'] as String,
      minAmount: json['min_amount'] != null ? json['min_amount'] as int : null,
      maxAmount: json['max_amount'] != null ? json['max_amount'] as int : null,
      fiatAmount: json['fiat_amount'] as int,
      paymentMethod: json['payment_method'] as String,
      premium: json['premium'] as int,
      buyerTradePubkey: json['buyer_trade_pubkey'] != null ? json['buyer_trade_pubkey'] as String : null,
      sellerTradePubkey: json['seller_trade_pubkey'] != null ? json['seller_trade_pubkey'] as String : null,
      createdAt: json['created_at'] != null ? json['created_at'] as int : null,
      expiresAt: json['expires_at'] != null ? json['expires_at'] as int : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'status': status,
        'amount': amount,
        'fiat_code': fiatCode,
        'min_amount': minAmount,
        'max_amount': maxAmount,
        'fiat_amount': fiatAmount,
        'payment_method': paymentMethod,
        'premium': premium,
        'buyer_trade_pubkey': buyerTradePubkey,
        'seller_trade_pubkey': sellerTradePubkey,
        'created_at': createdAt,
        'expires_at': expiresAt,
      };
}
