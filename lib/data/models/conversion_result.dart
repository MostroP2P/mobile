/// Represents the result of a currency conversion operation.
class ConversionResult {
  /// The original conversion request
  final ConversionRequest request;
  /// The converted amount
  final double result;
  /// The conversion rate used
  final double rate;
  /// Unix timestamp of when the conversion was performed
  final int timestamp;

  ConversionResult({
    required this.request,
    required this.result,
    required this.rate,
    required this.timestamp,
  }) {
    if (timestamp < 0) {
      throw ArgumentError('Timestamp cannot be negative');
    }
  }

  factory ConversionResult.fromJson(Map<String, dynamic> json) {
    if (json['request'] == null) {
      throw FormatException('Missing required field: request');
    }
    return ConversionResult(
      request: ConversionRequest.fromJson(json['request']),
      result: (json['result'] as num?)?.toDouble() ?? 0.0,
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] ? json['timestamp'] as int : 
        throw FormatException('Missing or invalid timestamp'),
    );
  }

  Map<String, dynamic> toJson() => {
    'request': request.toJson(),
    'result': result,
    'rate': rate,
    'timestamp': timestamp,
  };

  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is ConversionResult &&
    request == other.request &&
    result == other.result &&
    rate == other.rate &&
    timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(request, result, rate, timestamp);

  @override
  String toString() => 'ConversionResult('
    'request: $request, '
    'result: $result, '
    'rate: $rate, '
    'timestamp: $timestamp)';
}

/// Represents a request to convert between currencies.
class ConversionRequest {
  /// The amount to convert in the smallest unit of the currency
  final int amount;
  /// The currency code to convert from (ISO 4217)
  final String from;
  /// The currency code to convert to (ISO 4217)
  final String to;

  ConversionRequest({
    required this.amount,
    required this.from,
    required this.to,
  }) {
    if (amount < 0) {
      throw ArgumentError('Amount cannot be negative');
    }
    if (from.length != 3 || to.length != 3) {
      throw ArgumentError('Currency codes must be 3 characters (ISO 4217)');
    }
  }

  factory ConversionRequest.fromJson(Map<String, dynamic> json) {
    final amount = json['amount'] as int?;
    final from = json['from'] as String?;
    final to = json['to'] as String?;

    if (amount == null || from == null || to == null) {
      throw FormatException('Missing required fields');
    }

    return ConversionRequest(
      amount: amount,
      from: from.toUpperCase(),
      to: to.toUpperCase(),
    );
  }

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'from': from,
    'to': to,
  };

  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is ConversionRequest &&
    amount == other.amount &&
    from == other.from &&
    to == other.to;

  @override
  int get hashCode => Object.hash(amount, from, to);

  @override
  String toString() => 'ConversionRequest('
    'amount: $amount, '
    'from: $from, '
    'to: $to)';
}