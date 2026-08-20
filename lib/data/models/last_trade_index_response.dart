import 'package:mostro_mobile/data/models/payload.dart';

class LastTradeIndexResponse implements Payload {
  final int tradeIndex;
  final bool noHistoryFound;

  const LastTradeIndexResponse({
    required this.tradeIndex,
    this.noHistoryFound = false,
  });

  @override
  String get type => 'last-trade-index';

  factory LastTradeIndexResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['trade_index'];
    final tradeIndex = raw is int ? raw : (raw is num ? raw.toInt() : null);
    if (tradeIndex == null || tradeIndex < 0) {
      // A trade index is a count of keys derived; negative or non-numeric is
      // not a value the daemon can mean, and it feeds a key-derivation
      // counter, so it is refused here rather than clamped downstream.
      throw FormatException('Invalid trade_index: $raw');
    }
    return LastTradeIndexResponse(tradeIndex: tradeIndex);
  }

  @override
  Map<String, dynamic> toJson() => {
        'trade_index': tradeIndex,
      };
}
