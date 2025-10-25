import 'dart:convert';

class LastTradeIndexRequest {
  final int version;
  final String action;

  LastTradeIndexRequest({
    this.version = 1,
    this.action = 'last-trade-index',
  });

  String toJsonString() {
    return jsonEncode([
      {
        'restore': {
          'version': version,
          'action': action,
          'payload': null,
        }
      },
      null
    ]);
  }
}

class LastTradeIndexResponse {
  final int version;
  final String action;
  final int tradeIndex;

  LastTradeIndexResponse({
    required this.version,
    required this.action,
    required this.tradeIndex,
  });

  factory LastTradeIndexResponse.fromJson(Map<String, dynamic> json) {
    final restore = json['restore'] as Map<String, dynamic>;
    return LastTradeIndexResponse(
      version: restore['version'] as int,
      action: restore['action'] as String,
      tradeIndex: restore['trade_index'] as int,
    );
  }
}
