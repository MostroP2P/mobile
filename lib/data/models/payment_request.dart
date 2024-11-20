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
    
    final result = {
      typeKey: values
    };

    return result;
  }

  factory PaymentRequest.fromJson(List<dynamic> json) {
    return PaymentRequest(
        order: json[0] ?? Order.fromJson(json[0]),
        lnInvoice: json[1],
        amount: json[2]);
  }

  @override
  String get type => 'payment_request';
}
