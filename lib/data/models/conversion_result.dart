class ConversionResult {
  final ConversionRequest request;
  final double result;
  final double rate;
  final int timestamp;

  ConversionResult({
    required this.request,
    required this.result,
    required this.rate,
    required this.timestamp,
  });

  factory ConversionResult.fromJson(Map<String, dynamic> json) {
    return ConversionResult(
      request: ConversionRequest.fromJson(json['request']),
      result: (json['result'] as num).toDouble(),
      rate: (json['rate'] as num).toDouble(),
      timestamp: json['timestamp'],
    );
  }
}

class ConversionRequest {
  final int amount;
  final String from;
  final String to;

  ConversionRequest({
    required this.amount,
    required this.from,
    required this.to,
  });

  factory ConversionRequest.fromJson(Map<String, dynamic> json) {
    return ConversionRequest(
      amount: json['amount'],
      from: json['from'],
      to: json['to'],
    );
  }
}
