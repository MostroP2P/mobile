import 'package:mostro_mobile/data/models/enums/cant_do_reason.dart';
import 'package:mostro_mobile/data/models/payload.dart';

class CantDo implements Payload {
  final CantDoReason cantDoReason;

  factory CantDo.fromJson(Map<String, dynamic> json) {
    if (json['cant_do'] is String) {
      return CantDo(
        cantDoReason: CantDoReason.fromString(
          json['cant_do'],
        ),
      );
    } else {
      return CantDo(
        cantDoReason: CantDoReason.fromString(
          json['cant_do']['cant-do'],
        ),
      );
    }
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
