import 'package:mostro_mobile/data/models/cant_do.dart';
import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/data/models/next_trade.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/payment_failed.dart';
import 'package:mostro_mobile/data/models/payment_request.dart';
import 'package:mostro_mobile/data/models/peer.dart';
import 'package:mostro_mobile/data/models/rating_user.dart';

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
      return Peer.fromJson(json['peer']);
    } else if (json.containsKey('dispute')) {
      return Dispute.fromJson(json);
    } else if (json.containsKey('rating_user')) {
      return RatingUser.fromJson(json['rating_user']);
    } else if (json.containsKey('payment_failed')) {
      return PaymentFailed.fromJson(json['payment_failed']);
    } else if (json.containsKey('next_trade')) {
      return NextTrade.fromJson(json['next_trade']);
    } else {
      throw UnsupportedError('Unknown payload type');
    }
  }
}
