import 'package:mostro_mobile/data/models/payload.dart';

class CantDo implements Payload {
  final String cantDo;

  factory CantDo.fromJson(Map<String, dynamic> json) {
    return CantDo(cantDo: json['cant_do']);
  }

  CantDo({required this.cantDo});

  @override
  Map<String, dynamic> toJson() {
    return {
      type : {
        'cant-do' : cantDo,
      }
    };
  }

  @override
  String get type => 'cant_do';
}
