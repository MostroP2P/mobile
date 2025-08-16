import 'package:mostro_mobile/data/models/payload.dart';

class RestoreRequestPayload implements Payload {
  @override
  String get type => 'restore-request';

  @override
  Map<String, dynamic> toJson() => {
        'restore': {
          'version': 1,
          'action': 'restore-session',
          'payload': null,
        }
      };
}

class RestoreOrderItem {
  final String id;
  final int tradeIndex;
  final String status;

  RestoreOrderItem({required this.id, required this.tradeIndex, required this.status});

  factory RestoreOrderItem.fromJson(Map<String, dynamic> json) => RestoreOrderItem(
        id: json['id'] as String,
        tradeIndex: (json['trade_index'] as num).toInt(),
        status: json['status'] as String,
      );
}

class RestoreDisputeItem {
  final String disputeId;
  final String orderId;
  final int tradeIndex;
  final String status;

  RestoreDisputeItem({
    required this.disputeId,
    required this.orderId,
    required this.tradeIndex,
    required this.status,
  });

  factory RestoreDisputeItem.fromJson(Map<String, dynamic> json) => RestoreDisputeItem(
        disputeId: json['dispute_id'] as String,
        orderId: json['order_id'] as String,
        tradeIndex: (json['trade_index'] as num).toInt(),
        status: json['status'] as String,
      );
}

class RestoreSessionPayload implements Payload {
  final List<RestoreOrderItem> orders;
  final List<RestoreDisputeItem> disputes;

  RestoreSessionPayload({required this.orders, required this.disputes});

  @override
  String get type => 'restore-session';

  factory RestoreSessionPayload.fromJson(Map<String, dynamic> json) {
    // json is expected to be { 'restore': { version, action, payload: { orders: [...], disputes: [...] } } }
    final restore = json['restore'] as Map<String, dynamic>;
    final payload = restore['payload'] as Map<String, dynamic>?;
    final ordersJson = (payload?['orders'] as List<dynamic>? ?? []);
    final disputesJson = (payload?['disputes'] as List<dynamic>? ?? []);

    return RestoreSessionPayload(
      orders: ordersJson
          .whereType<Map<String, dynamic>>()
          .map(RestoreOrderItem.fromJson)
          .toList(growable: false),
      disputes: disputesJson
          .whereType<Map<String, dynamic>>()
          .map(RestoreDisputeItem.fromJson)
          .toList(growable: false),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'restore': {
          'version': 1,
          'action': 'restore-session',
          'payload': {
            'orders': orders
                .map((o) => {
                      'id': o.id,
                      'trade_index': o.tradeIndex,
                      'status': o.status,
                    })
                .toList(),
            'disputes': disputes
                .map((d) => {
                      'dispute_id': d.disputeId,
                      'order_id': d.orderId,
                      'trade_index': d.tradeIndex,
                      'status': d.status,
                    })
                .toList(),
          },
        }
      };

}
