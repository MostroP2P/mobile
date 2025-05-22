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
  final List<String> paymentMethods;
  final int premium;
  final String? masterBuyerPubkey;
  final String? masterSellerPubkey;
  final String? buyerTradePubkey;
  final String? sellerTradePubkey;
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
    required List<String> paymentMethods,
    this.premium = 0,
    this.masterBuyerPubkey,
    this.masterSellerPubkey,
    this.buyerTradePubkey,
    this.sellerTradePubkey,
    this.buyerInvoice,
    this.createdAt = 0,
    this.expiresAt,
    this.buyerToken,
    this.sellerToken,
  }) : this.paymentMethods = List<String>.from(paymentMethods);

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
        'payment_methods': paymentMethods,
        'premium': premium,
      }
    };

    if (id != null) data[type]['id'] = id;

    if (buyerInvoice != null) data[type]['buyer_invoice'] = buyerInvoice;

    data[type]['created_at'] = createdAt;
    data[type]['expires_at'] = expiresAt;
    data[type]['buyer_token'] = buyerToken;
    data[type]['seller_token'] = sellerToken;

    if (buyerTradePubkey != null) {
      data[type]['buyer_trade_pubkey'] = buyerTradePubkey;
    }
    if (sellerTradePubkey != null) {
      data[type]['seller_trade_pubkey'] = sellerTradePubkey;
    }
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
    ['kind', 'status', 'fiat_code', 'fiat_amount', 'payment_methods', 'premium']
        .forEach(validateField);

    // Handle payment methods - could be a string or a list
    List<String> paymentMethods;
    if (json['payment_methods'] is List) {
      paymentMethods = List<String>.from(json['payment_methods']);
    } else if (json['payment_methods'] is String) {
      paymentMethods = (json['payment_methods'] as String).split(',');
    } else if (json['payment_method'] is String) {
      // For backward compatibility
      paymentMethods = (json['payment_method'] as String).split(',');
    } else {
      paymentMethods = [];
    }

    return Order(
      id: json['id'],
      kind: OrderType.fromString(json['kind'].toString()),
      status: Status.fromString(json['status']),
      amount: json['amount'],
      fiatCode: json['fiat_code'],
      minAmount: json['min_amount'],
      maxAmount: json['max_amount'],
      fiatAmount: json['fiat_amount'],
      paymentMethods: paymentMethods,
      premium: json['premium'],
      masterBuyerPubkey: json['master_buyer_pubkey'],
      masterSellerPubkey: json['master_seller_pubkey'],
      buyerTradePubkey: json['buyer_trade_pubkey'],
      sellerTradePubkey: json['seller_trade_pubkey'],
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
      status: event.status,
      amount: event.amount as int,
      fiatCode: event.currency!,
      fiatAmount: event.fiatAmount.minimum,
      paymentMethods: event.paymentMethods,
      premium: event.premium as int,
      createdAt: event.createdAt as int,
      expiresAt: event.expiration as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kind': kind.value, // from OrderType
      'status': status.value, // from Status
      'amount': amount,
      'fiatCode': fiatCode,
      'minAmount': minAmount,
      'maxAmount': maxAmount,
      'fiatAmount': fiatAmount,
      'paymentMethods': paymentMethods,
      'premium': premium,
      'masterBuyerPubkey': masterBuyerPubkey,
      'masterSellerPubkey': masterSellerPubkey,
      'buyerInvoice': buyerInvoice,
      'createdAt': createdAt,
      'expiresAt': expiresAt,
      'buyerToken': buyerToken,
      'sellerToken': sellerToken,
    };
  }

  // Construct from a Map (row in DB)
  factory Order.fromMap(Map<String, dynamic> map) {
    // Handle payment methods - could be a string or a list
    List<String> paymentMethods;
    if (map['paymentMethods'] is List) {
      paymentMethods = List<String>.from(map['paymentMethods']);
    } else if (map['paymentMethods'] is String) {
      paymentMethods = (map['paymentMethods'] as String).split(',');
    } else if (map['paymentMethod'] is String) {
      // For backward compatibility
      paymentMethods = (map['paymentMethod'] as String).split(',');
    } else {
      paymentMethods = [];
    }

    return Order(
      id: map['id'] as String?,
      kind: OrderType.fromString(map['kind'] as String),
      status: Status.fromString(map['status'] as String),
      amount: map['amount'] as int,
      fiatCode: map['fiatCode'] as String,
      minAmount: map['minAmount'] as int?,
      maxAmount: map['maxAmount'] as int?,
      fiatAmount: map['fiatAmount'] as int,
      paymentMethods: paymentMethods,
      premium: map['premium'] as int,
      masterBuyerPubkey: map['masterBuyerPubkey'] as String?,
      masterSellerPubkey: map['masterSellerPubkey'] as String?,
      buyerInvoice: map['buyerInvoice'] as String?,
      createdAt: map['createdAt'] as int?,
      expiresAt: map['expiresAt'] as int?,
      buyerToken: map['buyerToken'] as int?,
      sellerToken: map['sellerToken'] as int?,
    );
  }

  @override
  String get type => 'order';

  Order copyWith({String? buyerInvoice}) {
    return Order(
      id: id,
      kind: kind,
      status: status,
      amount: amount,
      fiatCode: fiatCode,
      minAmount: minAmount,
      maxAmount: maxAmount,
      fiatAmount: fiatAmount,
      paymentMethods: paymentMethods,
      premium: premium,
      masterBuyerPubkey: masterBuyerPubkey,
      masterSellerPubkey: masterSellerPubkey,
      buyerTradePubkey: buyerTradePubkey,
      sellerTradePubkey: sellerTradePubkey,
      buyerInvoice: buyerInvoice ?? this.buyerInvoice,
      createdAt: createdAt,
      expiresAt: expiresAt,
      buyerToken: buyerToken,
      sellerToken: sellerToken,
    );
  }
}
