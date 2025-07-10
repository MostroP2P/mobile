import 'package:mostro_mobile/data/models/payload.dart';
import 'package:mostro_mobile/data/models/order.dart';

class PaymentRequest implements Payload {
  final Order? order;
  final String? lnInvoice;
  final int? amount;

  PaymentRequest({
    this.order,
    this.lnInvoice,
    this.amount,
  }) {
    // At least one parameter should be non-null
    if (order == null && lnInvoice == null && amount == null) {
      throw ArgumentError('At least one parameter must be provided');
    }
  }

  @override
  Map<String, dynamic> toJson() {
    final typeKey = type;
    final List<dynamic> values = [];

    values.add(order?.toJson());
    values.add(lnInvoice);

    if (amount != null) {
      values.add(amount);
    }

    final result = {typeKey: values};

    return result;
  }

  factory PaymentRequest.fromJson(List<dynamic> json) {
    try {
      if (json.length < 2) {
        throw FormatException('Invalid JSON format: insufficient elements (expected at least 2, got ${json.length})');
      }

      // Parse order
      final orderJson = json[0];
      Order? order;
      if (orderJson != null) {
        if (orderJson is Map<String, dynamic>) {
          order = Order.fromJson(orderJson['order'] ?? orderJson);
        } else {
          throw FormatException('Invalid order type: ${orderJson.runtimeType}');
        }
      }

      // Parse lnInvoice
      final lnInvoice = json[1];
      if (lnInvoice != null && lnInvoice is! String) {
        throw FormatException('Invalid type for lnInvoice: expected String, got ${lnInvoice.runtimeType}');
      }
      if (lnInvoice is String && lnInvoice.isEmpty) {
        throw FormatException('lnInvoice cannot be empty string');
      }

      // Parse amount (optional)
      int? amount;
      if (json.length > 2) {
        final amountValue = json[2];
        if (amountValue != null) {
          if (amountValue is int) {
            amount = amountValue;
          } else if (amountValue is String) {
            amount = int.tryParse(amountValue) ??
                (throw FormatException('Invalid amount format: $amountValue'));
          } else {
            throw FormatException('Invalid amount type: ${amountValue.runtimeType}');
          }
          if (amount < 0) {
            throw FormatException('Amount cannot be negative: $amount');
          }
        }
      }

      return PaymentRequest(
        order: order,
        lnInvoice: lnInvoice,
        amount: amount,
      );
    } catch (e) {
      throw FormatException('Failed to parse PaymentRequest from JSON: $e');
    }
  }

  @override
  String get type => 'payment_request';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PaymentRequest &&
        other.order == order &&
        other.lnInvoice == lnInvoice &&
        other.amount == amount;
  }
  
  @override
  int get hashCode => Object.hash(order, lnInvoice, amount);
  
  @override
  String toString() {
    return 'PaymentRequest(order: $order, lnInvoice: $lnInvoice, amount: $amount)';
  }
}
