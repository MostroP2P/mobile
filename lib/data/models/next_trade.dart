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
      type: {'key': key, 'index': index},
    };
  }

  factory NextTrade.fromJson(Map<String, dynamic> json) {
    return NextTrade(
      key: json['key'] as String,
      index: json['index'] as int,
    );
  }
  
}
