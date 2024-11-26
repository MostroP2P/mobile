import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/payment_request.dart';

abstract class Content {
  String get type;
  Map<String, dynamic> toJson();

  factory Content.fromJson(Map<String, dynamic> json) {fromJson
    if (json.containsKey('order')) {
      return Order.fromJson(json['order']);
    } else if (json.containsKey('payment_request')) {
      return PaymentRequest.fromJson(json['payment_request']);
    }
    throw UnsupportedError('Unknown content type');
  }
}
