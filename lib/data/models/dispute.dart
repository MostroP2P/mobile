import 'package:mostro_mobile/data/models/payload.dart';

class Dispute implements Payload {
  final String orderId;

  Dispute({required this.orderId});

  @override
  Map<String, dynamic> toJson() {
    return {
      type: orderId,
    };
  }

  @override
  String get type => 'dispute';
}
