import 'package:mostro_mobile/data/models/payload.dart';

class LastTradeIndexResponse implements Payload {
  final int tradeIndex;

  const LastTradeIndexResponse({required this.tradeIndex});

  @override
  String get type => 'last-trade-index';

  factory LastTradeIndexResponse.fromJson(Map<String, dynamic> json) {
    return LastTradeIndexResponse(
      tradeIndex: json['trade_index'] as int,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'trade_index': tradeIndex,
      };
}
