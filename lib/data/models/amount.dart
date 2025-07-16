import 'package:mostro_mobile/data/models/payload.dart';

class Amount implements Payload {
  final int amount;

  Amount({required this.amount}) {
    if (amount < 0) {
      throw ArgumentError('Amount cannot be negative: $amount');
    }
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      type: amount,
    };
  }

  factory Amount.fromJson(dynamic json) {
    try {
      if (json == null) {
        throw FormatException('Amount JSON cannot be null');
      }
      
      int amountValue;
      if (json is Map<String, dynamic>) {
        if (!json.containsKey('amount')) {
          throw FormatException('Missing required field: amount');
        }
        final value = json['amount'];
        if (value is int) {
          amountValue = value;
        } else if (value is String) {
          amountValue = int.tryParse(value) ?? 
            (throw FormatException('Invalid amount format: $value'));
        } else {
          throw FormatException('Invalid amount type: ${value.runtimeType}');
        }
      } else if (json is int) {
        amountValue = json;
      } else if (json is String) {
        amountValue = int.tryParse(json) ?? 
          (throw FormatException('Invalid amount format: $json'));
      } else {
        throw FormatException('Invalid JSON type for Amount: ${json.runtimeType}');
      }
      
      return Amount(amount: amountValue);
    } catch (e) {
      throw FormatException('Failed to parse Amount from JSON: $e');
    }
  }

  @override
  String get type => 'amount';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Amount && other.amount == amount;
  }
  
  @override
  int get hashCode => amount.hashCode;
  
  @override
  String toString() => 'Amount(amount: $amount)';
}
