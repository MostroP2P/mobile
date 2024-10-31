import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/content.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';

class Order implements Content {
  final String? id;
  final OrderType kind;
  final Status status;
  final int amount;
  final String fiatCode;
  final int? minAmount;
  final int? maxAmount;
  final int fiatAmount;
  final String paymentMethod;
  final int premium;
  final String? masterBuyerPubkey;
  final String? masterSellerPubkey;
  final String? buyerInvoice;
  final int? createdAt;
  final int? expiresAt;
  final int? buyerToken;
  final int? sellerToken;

  Order({
    this.id,
    required this.kind,
    this.status = Status.pending,
    this.amount = 0,
    required this.fiatCode,
    this.minAmount,
    this.maxAmount,
    required this.fiatAmount,
    required this.paymentMethod,
    required this.premium,
    this.masterBuyerPubkey,
    this.masterSellerPubkey,
    this.buyerInvoice,
    this.createdAt,
    this.expiresAt,
    this.buyerToken,
    this.sellerToken,
  });

  @override
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      type: {
        'kind': kind.value,
        'status': status.value,
        'amount': amount,
        'fiat_code': fiatCode,
        'fiat_amount': fiatAmount,
        'payment_method': paymentMethod,
        'premium': premium,
      }
    };

    if (id != null) data[type]['id'] = id;
    if (minAmount != null) data[type]['min_amount'] = minAmount;
    if (maxAmount != null) data[type]['max_amount'] = maxAmount;
    if (masterBuyerPubkey != null) {
      data[type]['master_buyer_pubkey'] = masterBuyerPubkey;
    }
    if (masterSellerPubkey != null) {
      data[type]['master_seller_pubkey'] = masterSellerPubkey;
    }
    if (buyerInvoice != null) data[type]['buyer_invoice'] = buyerInvoice;
    if (createdAt != null) data[type]['created_at'] = createdAt;
    if (expiresAt != null) data[type]['expires_at'] = expiresAt;
    if (buyerToken != null) data[type]['buyer_token'] = buyerToken;
    if (sellerToken != null) data[type]['seller_token'] = sellerToken;

    return data;
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String?,
      kind: OrderType.fromString(json['kind'] as String),
      status: Status.fromString(json['status'] as String),
      amount: json['amount'] as int,
      fiatCode: json['fiat_code'] as String,
      minAmount: json['min_amount'] as int?,
      maxAmount: json['max_amount'] as int?,
      fiatAmount: json['fiat_amount'] as int,
      paymentMethod: json['payment_method'] as String,
      premium: json['premium'] as int,
      masterBuyerPubkey: json['master_buyer_pubkey'] as String?,
      masterSellerPubkey: json['master_seller_pubkey'] as String?,
      buyerInvoice: json['buyer_invoice'] as String?,
      createdAt: json['created_at'] as int?,
      expiresAt: json['expires_at'] as int?,
      buyerToken: json['buyer_token'] as int?,
      sellerToken: json['seller_token'] as int?,
    );
  }

  factory Order.fromEvent(NostrEvent event) {
    return Order(
      id: event.orderId,
      kind: OrderType.fromString(event.orderType!),
      status: Status.fromString(event.status!),
      amount: event.amount as int,
      fiatCode: event.currency!,
      fiatAmount: int.parse(event.fiatAmount!),
      paymentMethod: event.paymentMethods.join(','),
      premium: event.premium as int,
      createdAt: event.createdAt as int,
      expiresAt: event.expiration as int?,
    );
  }

  @override
  String get type => 'order';
}
