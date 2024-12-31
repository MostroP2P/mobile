import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/payload.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';

class Order implements Payload {
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
    this.premium = 1,
    this.masterBuyerPubkey,
    this.masterSellerPubkey,
    this.buyerInvoice,
    this.createdAt = 0,
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
        'min_amount': minAmount,
        'max_amount': maxAmount,
        'fiat_amount': fiatAmount,
        'payment_method': paymentMethod,
        'premium': premium,
        'created_at': createdAt,
        'expires_at': expiresAt,
        'buyer_token': buyerToken,
        'seller_token': sellerToken,
      }
    };

    if (id != null) data[type]['id'] = id;
    if (masterBuyerPubkey != null) {
      data[type]['master_buyer_pubkey'] = masterBuyerPubkey;
    }
    if (masterSellerPubkey != null) {
      data[type]['master_seller_pubkey'] = masterSellerPubkey;
    }
    if (buyerInvoice != null) data[type]['buyer_invoice'] = buyerInvoice;
    return data;
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    // Validate required fields
    void validateField(String field) {
      if (!json.containsKey(field)) {
        throw FormatException('Missing required field: $field');
      }
    }

    // Validate required fields
    ['kind', 'status', 'fiat_code', 'fiat_amount', 'payment_method', 'premium']
        .forEach(validateField);

    // Safe type casting
    T? safeCast<T>(String key, T Function(dynamic) converter) {
      final value = json[key];
      return value == null ? null : converter(value);
    }

    return Order(
      id: safeCast<String>('id', (v) => v.toString()),
      kind: OrderType.fromString(json['kind'].toString()),
      status: Status.fromString(json['status']),
      amount: json['amount'],
      fiatCode: json['fiat_code'],
      minAmount: json['min_amount'],
      maxAmount: json['max_amount'],
      fiatAmount: json['fiat_amount'],
      paymentMethod: json['payment_method'],
      premium: json['premium'],
      masterBuyerPubkey: json['master_buyer_pubkey'],
      masterSellerPubkey: json['master_seller_pubkey'],
      buyerInvoice: json['buyer_invoice'],
      createdAt: json['created_at'],
      expiresAt: json['expires_at'],
      buyerToken: json['buyer_token'],
      sellerToken: json['seller_token'],
    );
  }

  factory Order.fromEvent(NostrEvent event) {
    return Order(
      id: event.orderId,
      kind: event.orderType!,
      status: Status.fromString(event.status!),
      amount: event.amount as int,
      fiatCode: event.currency!,
      fiatAmount: event.fiatAmount.minimum,
      paymentMethod: event.paymentMethods.join(','),
      premium: event.premium as int,
      createdAt: event.createdAt as int,
      expiresAt: event.expiration as int?,
    );
  }

  @override
  String get type => 'order';
}
