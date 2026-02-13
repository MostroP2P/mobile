import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:mostro_mobile/services/nwc/nwc_exceptions.dart';

// ---------------------------------------------------------------------------
// NWC Request
// ---------------------------------------------------------------------------

/// A NIP-47 request payload (the JSON content encrypted inside kind 23194).
class NwcRequest extends Equatable {
  final String method;
  final Map<String, dynamic> params;

  const NwcRequest({required this.method, required this.params});

  Map<String, dynamic> toMap() => {'method': method, 'params': params};

  String toJson() => jsonEncode(toMap());

  factory NwcRequest.fromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return NwcRequest(
      method: map['method'] as String,
      params: (map['params'] as Map<String, dynamic>?) ?? {},
    );
  }

  @override
  List<Object?> get props => [method, params];
}

// ---------------------------------------------------------------------------
// NWC Response
// ---------------------------------------------------------------------------

/// A NIP-47 response payload (the JSON content decrypted from kind 23195).
class NwcResponse extends Equatable {
  final String resultType;
  final NwcError? error;
  final Map<String, dynamic>? result;

  const NwcResponse({
    required this.resultType,
    this.error,
    this.result,
  });

  bool get isSuccess => error == null;

  Map<String, dynamic> toMap() => {
        'result_type': resultType,
        'error': error?.toMap(),
        'result': result,
      };

  String toJson() => jsonEncode(toMap());

  factory NwcResponse.fromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return NwcResponse.fromMap(map);
  }

  factory NwcResponse.fromMap(Map<String, dynamic> map) {
    NwcError? error;
    if (map['error'] != null) {
      error = NwcError.fromMap(map['error'] as Map<String, dynamic>);
    }

    return NwcResponse(
      resultType: map['result_type'] as String,
      error: error,
      result: map['result'] as Map<String, dynamic>?,
    );
  }

  @override
  List<Object?> get props => [resultType, error, result];
}

/// Error object inside a NWC response.
class NwcError extends Equatable {
  final NwcErrorCode code;
  final String message;

  const NwcError({required this.code, required this.message});

  Map<String, dynamic> toMap() => {
        'code': code.value,
        'message': message,
      };

  factory NwcError.fromMap(Map<String, dynamic> map) {
    return NwcError(
      code: NwcErrorCode.fromString(map['code'] as String),
      message: map['message'] as String,
    );
  }

  @override
  List<Object?> get props => [code, message];
}

// ---------------------------------------------------------------------------
// Command-specific param / result models
// ---------------------------------------------------------------------------

/// Parameters for `pay_invoice`.
class PayInvoiceParams extends Equatable {
  final String invoice;
  final int? amount; // msats, optional
  final Map<String, dynamic>? metadata;

  const PayInvoiceParams({
    required this.invoice,
    this.amount,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{'invoice': invoice};
    if (amount != null) map['amount'] = amount;
    if (metadata != null) map['metadata'] = metadata;
    return map;
  }

  @override
  List<Object?> get props => [invoice, amount, metadata];
}

/// Result of `pay_invoice`.
class PayInvoiceResult extends Equatable {
  final String preimage;
  final int? feesPaid; // msats

  const PayInvoiceResult({required this.preimage, this.feesPaid});

  factory PayInvoiceResult.fromMap(Map<String, dynamic> map) {
    return PayInvoiceResult(
      preimage: map['preimage'] as String,
      feesPaid: map['fees_paid'] as int?,
    );
  }

  @override
  List<Object?> get props => [preimage, feesPaid];
}

/// Parameters for `make_invoice`.
class MakeInvoiceParams extends Equatable {
  final int amount; // msats
  final String? description;
  final String? descriptionHash;
  final int? expiry; // seconds
  final Map<String, dynamic>? metadata;

  const MakeInvoiceParams({
    required this.amount,
    this.description,
    this.descriptionHash,
    this.expiry,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{'amount': amount};
    if (description != null) map['description'] = description;
    if (descriptionHash != null) map['description_hash'] = descriptionHash;
    if (expiry != null) map['expiry'] = expiry;
    if (metadata != null) map['metadata'] = metadata;
    return map;
  }

  @override
  List<Object?> get props =>
      [amount, description, descriptionHash, expiry, metadata];
}

/// Result of `make_invoice` and `lookup_invoice`.
class TransactionResult extends Equatable {
  final String type; // "incoming" or "outgoing"
  final String? state;
  final String? invoice;
  final String? description;
  final String? descriptionHash;
  final String? preimage;
  final String? paymentHash;
  final int amount; // msats
  final int? feesPaid; // msats
  final int createdAt; // unix timestamp
  final int? expiresAt;
  final int? settledAt;
  final Map<String, dynamic>? metadata;

  const TransactionResult({
    required this.type,
    this.state,
    this.invoice,
    this.description,
    this.descriptionHash,
    this.preimage,
    this.paymentHash,
    required this.amount,
    this.feesPaid,
    required this.createdAt,
    this.expiresAt,
    this.settledAt,
    this.metadata,
  });

  factory TransactionResult.fromMap(Map<String, dynamic> map) {
    return TransactionResult(
      type: map['type'] as String,
      state: map['state'] as String?,
      invoice: map['invoice'] as String?,
      description: map['description'] as String?,
      descriptionHash: map['description_hash'] as String?,
      preimage: map['preimage'] as String?,
      paymentHash: map['payment_hash'] as String?,
      amount: map['amount'] as int,
      feesPaid: map['fees_paid'] as int?,
      createdAt: map['created_at'] as int,
      expiresAt: map['expires_at'] as int?,
      settledAt: map['settled_at'] as int?,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  List<Object?> get props => [
        type,
        state,
        invoice,
        description,
        descriptionHash,
        preimage,
        paymentHash,
        amount,
        feesPaid,
        createdAt,
        expiresAt,
        settledAt,
        metadata,
      ];
}

/// Parameters for `lookup_invoice`.
class LookupInvoiceParams extends Equatable {
  final String? paymentHash;
  final String? invoice;

  const LookupInvoiceParams({this.paymentHash, this.invoice});

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    if (paymentHash != null) map['payment_hash'] = paymentHash;
    if (invoice != null) map['invoice'] = invoice;
    return map;
  }

  @override
  List<Object?> get props => [paymentHash, invoice];
}

/// Result of `get_balance`.
class GetBalanceResult extends Equatable {
  final int balance; // msats

  const GetBalanceResult({required this.balance});

  factory GetBalanceResult.fromMap(Map<String, dynamic> map) {
    return GetBalanceResult(balance: map['balance'] as int);
  }

  @override
  List<Object?> get props => [balance];
}

/// Result of `get_info`.
class GetInfoResult extends Equatable {
  final String? alias;
  final String? color;
  final String? pubkey;
  final String? network;
  final int? blockHeight;
  final String? blockHash;
  final List<String> methods;
  final List<String>? notifications;

  const GetInfoResult({
    this.alias,
    this.color,
    this.pubkey,
    this.network,
    this.blockHeight,
    this.blockHash,
    required this.methods,
    this.notifications,
  });

  factory GetInfoResult.fromMap(Map<String, dynamic> map) {
    return GetInfoResult(
      alias: map['alias'] as String?,
      color: map['color'] as String?,
      pubkey: map['pubkey'] as String?,
      network: map['network'] as String?,
      blockHeight: map['block_height'] as int?,
      blockHash: map['block_hash'] as String?,
      methods: (map['methods'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      notifications: (map['notifications'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );
  }

  @override
  List<Object?> get props => [
        alias,
        color,
        pubkey,
        network,
        blockHeight,
        blockHash,
        methods,
        notifications,
      ];
}
