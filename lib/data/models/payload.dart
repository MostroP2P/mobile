import 'package:mostro_mobile/data/models/cant_do.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/payment_request.dart';
import 'package:mostro_mobile/data/models/peer.dart';

abstract class Payload {
  String get type;
  Map<String, dynamic> toJson();

  factory Payload.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('order')) {
      return Order.fromJson(json['order']);
    } else if (json.containsKey('payment_request')) {
      return PaymentRequest.fromJson(json['payment_request']);
    } else if (json.containsKey('cant_do')) {
      return CantDo.fromJson(json);
    } else if (json.containsKey('peer')) {
      return Peer.fromJson(json);
    }
    throw UnsupportedError('Unknown content type');
  }
}
