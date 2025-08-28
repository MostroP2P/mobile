import 'package:mostro_mobile/data/models/payload.dart';

class NextTrade implements Payload {
  final String key;
  final int index;

  NextTrade({required this.key, required this.index});

  @override
  String get type => 'next_trade';

  @override
  Map<String, dynamic> toJson() {
    return {
      type: [key, index],
    };
  }

  factory NextTrade.fromJson(dynamic json) {
    if (json is List && json.length == 2) {
      return NextTrade(
        key: json[0] as String,
        index: json[1] as int,
      );
    } else {
      throw FormatException('Invalid NextTrade format: $json');
    }
  }
}
