import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/payment_request.dart';

abstract class Payload {
  String get type;
  Map<String, dynamic> toJson();

  factory Payload.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('order')) {
      return Order.fromJson(json['order']);
    } else if (json.containsKey('payment_request')) {
      return PaymentRequest.fromJson(json['payment_request']);
    }
    throw UnsupportedError('Unknown content type');
  }
}
