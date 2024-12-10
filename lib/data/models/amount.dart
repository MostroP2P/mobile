import 'package:mostro_mobile/data/models/payload.dart';

class Amount implements Payload {
  final int amount;

  Amount({required this.amount});

  @override
  Map<String, dynamic> toJson() {
    return {
      type: amount,
    };
  }

  @override
  String get type => 'amount';
}
