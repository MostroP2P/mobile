import 'package:mostro_mobile/data/models/enums/cant_do_reason.dart';
import 'package:mostro_mobile/data/models/payload.dart';

class CantDo implements Payload {
  final CantDoReason cantDoReason;

  factory CantDo.fromJson(Map<String, dynamic> json) {
    return CantDo(cantDoReason: json['cant_do']);
  }

  CantDo({required this.cantDoReason});

  @override
  Map<String, dynamic> toJson() {
    return {
      type: {
        'cant-do': cantDoReason.toString(),
      }
    };
  }

  @override
  String get type => 'cant_do';
}
