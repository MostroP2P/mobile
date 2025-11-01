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
  final String? buyerTradePubkey;
  final String? sellerTradePubkey;
  final String? buyerInvoice;
  final int? createdAt;
  final int? expiresAt;

  const Order({
    this.id,
    required this.kind,
    this.status = Status.pending,
    this.amount = 0,
    required this.fiatCode,
    this.minAmount,
    this.maxAmount,
    required this.fiatAmount,
    required this.paymentMethod,
    this.premium = 0,
    this.masterBuyerPubkey,
    this.masterSellerPubkey,
    this.buyerTradePubkey,
    this.sellerTradePubkey,
    this.buyerInvoice,
    this.createdAt = 0,
    this.expiresAt,
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
      }
    };

    if (id != null) data[type]['id'] = id;

    if (buyerInvoice != null) data[type]['buyer_invoice'] = buyerInvoice;

    data[type]['created_at'] = createdAt;
    data[type]['expires_at'] = expiresAt;

    if (buyerTradePubkey != null) {
      data[type]['buyer_trade_pubkey'] = buyerTradePubkey;
    }
    if (sellerTradePubkey != null) {
      data[type]['seller_trade_pubkey'] = sellerTradePubkey;
    }
    return data;
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    try {
      // Validate required fields
      void validateField(String field) {
        if (!json.containsKey(field) || json[field] == null) {
          throw FormatException('Missing required field: $field');
        }
      }

      // Validate required fields
      ['kind', 'status', 'fiat_code', 'fiat_amount', 'payment_method']
          .forEach(validateField);

      // Parse and validate integer fields with type safety
      int parseIntField(String field, {int defaultValue = 0}) {
        final value = json[field];
        if (value == null) return defaultValue;
        if (value is int) return value;
        if (value is String) {
          return int.tryParse(value) ??
              (throw FormatException('Invalid $field format: $value'));
        }
        throw FormatException('Invalid $field type: ${value.runtimeType}');
      }

      // Parse and validate string fields
      String parseStringField(String field) {
        final value = json[field];
        if (value == null) {
          throw FormatException('Missing required field: $field');
        }
        final stringValue = value.toString();
        if (stringValue.isEmpty) {
          throw FormatException('Field $field cannot be empty');
        }
        return stringValue;
      }

      // Parse optional string fields
      String? parseOptionalStringField(String field) {
        final value = json[field];
        return value?.toString();
      }

      // Parse optional integer fields
      int? parseOptionalIntField(String field) {
        final value = json[field];
        if (value == null) return null;
        if (value is int) return value;
        if (value is String) {
          return int.tryParse(value);
        }
        return null;
      }

      final amount = parseIntField('amount');
      final fiatAmount = parseIntField('fiat_amount');
      final premium = parseIntField('premium');

      // Validate amounts are not negative
      if (amount < 0) {
        throw FormatException('Amount cannot be negative: $amount');
      }
      if (fiatAmount < 0) {
        throw FormatException('Fiat amount cannot be negative: $fiatAmount');
      }

      final minAmount = parseOptionalIntField('min_amount');
      final maxAmount = parseOptionalIntField('max_amount');

      // Validate min/max amount relationship
      if (minAmount != null && minAmount < 0) {
        throw FormatException('Min amount cannot be negative: $minAmount');
      }
      if (maxAmount != null && maxAmount < 0) {
        throw FormatException('Max amount cannot be negative: $maxAmount');
      }
      if (minAmount != null && maxAmount != null && minAmount > maxAmount) {
        throw FormatException(
            'Min amount ($minAmount) cannot be greater than max amount ($maxAmount)');
      }

      return Order(
        id: parseOptionalStringField('id'),
        kind: OrderType.fromString(parseStringField('kind')),
        status: Status.fromString(parseStringField('status')),
        amount: amount,
        fiatCode: parseStringField('fiat_code'),
        minAmount: minAmount,
        maxAmount: maxAmount,
        fiatAmount: fiatAmount,
        paymentMethod: parseStringField('payment_method'),
        premium: premium,
        masterBuyerPubkey: parseOptionalStringField('master_buyer_pubkey'),
        masterSellerPubkey: parseOptionalStringField('master_seller_pubkey'),
        buyerTradePubkey: parseOptionalStringField('buyer_trade_pubkey'),
        sellerTradePubkey: parseOptionalStringField('seller_trade_pubkey'),
        buyerInvoice: parseOptionalStringField('buyer_invoice'),
        createdAt: parseOptionalIntField('created_at'),
        expiresAt: parseOptionalIntField('expires_at'),
      );
    } catch (e) {
      throw FormatException('Failed to parse Order from JSON: $e');
    }
  }

  factory Order.fromEvent(NostrEvent event) {
    return Order(
      id: event.orderId,
      kind: event.orderType!,
      status: event.status,
      amount: event.amount as int,
      fiatCode: event.currency!,
      fiatAmount: event.fiatAmount.minimum,
      paymentMethod: event.paymentMethods.join(','),
      premium: event.premium as int,
      createdAt: event.createdAt as int,
      expiresAt: event.orderExpiresAt != null
          ? int.tryParse(event.orderExpiresAt!)
          : null,
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
      'paymentMethod': paymentMethod,
      'premium': premium,
      'masterBuyerPubkey': masterBuyerPubkey,
      'masterSellerPubkey': masterSellerPubkey,
      'buyerInvoice': buyerInvoice,
      'createdAt': createdAt,
      'expiresAt': expiresAt,
    };
  }

  // Construct from a Map (row in DB)
  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['id'] as String?,
      kind: OrderType.fromString(map['kind'] as String),
      status: Status.fromString(map['status'] as String),
      amount: map['amount'] as int,
      fiatCode: map['fiatCode'] as String,
      minAmount: map['minAmount'] as int?,
      maxAmount: map['maxAmount'] as int?,
      fiatAmount: map['fiatAmount'] as int,
      paymentMethod: map['paymentMethod'] as String,
      premium: map['premium'] as int,
      masterBuyerPubkey: map['masterBuyerPubkey'] as String?,
      masterSellerPubkey: map['masterSellerPubkey'] as String?,
      buyerInvoice: map['buyerInvoice'] as String?,
      createdAt: map['createdAt'] as int?,
      expiresAt: map['expiresAt'] as int?,
    );
  }

  @override
  String get type => 'order';

  Order copyWith({String? buyerInvoice, Status? status}) {
    return Order(
      id: id,
      kind: kind,
      status: status ?? this.status,
      amount: amount,
      fiatCode: fiatCode,
      minAmount: minAmount,
      maxAmount: maxAmount,
      fiatAmount: fiatAmount,
      paymentMethod: paymentMethod,
      premium: premium,
      masterBuyerPubkey: masterBuyerPubkey,
      masterSellerPubkey: masterSellerPubkey,
      buyerTradePubkey: buyerTradePubkey,
      sellerTradePubkey: sellerTradePubkey,
      buyerInvoice: buyerInvoice ?? this.buyerInvoice,
      expiresAt: expiresAt,
      createdAt: createdAt,
    );
  }
}
