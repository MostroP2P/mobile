import 'package:mostro_mobile/data/models/content.dart';
import 'package:mostro_mobile/data/models/order.dart';

class PaymentRequest implements Content {
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
    if (json.length < 2) {
      throw FormatException('Invalid JSON format: insufficient elements');
    }
    final orderJson = json[0];
    final Order? order = orderJson != null ? Order.fromJson(orderJson) : null;
    final lnInvoice = json[1];
    if (lnInvoice != null && lnInvoice is! String) {
      throw FormatException('Invalid type for lnInvoice: expected String');
    }
    final amount = json.length > 2 ? json[2] as int? : null;
    return PaymentRequest(
      order: order,
      lnInvoice: lnInvoice as String?,
      amount: amount,
    );
  }

  @override
  String get type => 'payment_request';
}
