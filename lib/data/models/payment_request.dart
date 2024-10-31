import 'package:mostro_mobile/data/models/content.dart';
import 'package:mostro_mobile/data/models/order.dart';

class PaymentRequest implements Content {
  final Order? order;
  final String? lnInvoice;
  final int? amount;

  PaymentRequest(
      {required this.order, required this.lnInvoice, required this.amount});

  @override
  Map<String, dynamic> toJson() {
    final result = {
      type: [order?.toJson(), lnInvoice]
    };

    if (amount != null) {
      result[type]!.add(amount);
    }

    return result;
  }

  @override
  String get type => 'payment_request';
}
