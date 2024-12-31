import 'package:mostro_mobile/data/models/payload.dart';

class CantDo implements Payload {
  final String cantDo;

  factory CantDo.fromJson(Map<String, dynamic> json) {
    return CantDo(cantDo: json['cant_do']);
  }

  CantDo({required this.cantDo});

  @override
  Map<String, dynamic> toJson() {
    // TODO: implement toJson
    throw UnimplementedError();
  }

  @override
  // TODO: implement type
  String get type => 'can_do';
}
