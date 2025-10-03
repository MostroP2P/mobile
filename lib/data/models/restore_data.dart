import 'package:mostro_mobile/data/models/payload.dart';

class RestoreOrderInfo {
  final String orderId;
  final int tradeIndex;
  final String status;

  RestoreOrderInfo({
    required this.orderId,
    required this.tradeIndex,
    required this.status,
  });

  factory RestoreOrderInfo.fromJson(Map<String, dynamic> json) {
    return RestoreOrderInfo(
      orderId: json['order_id'] as String,
      tradeIndex: json['trade_index'] as int,
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      'trade_index': tradeIndex,
      'status': status,
    };
  }
}

class RestoreDisputeInfo {
  final String disputeId;
  final String orderId;
  final int tradeIndex;
  final String status;

  RestoreDisputeInfo({
    required this.disputeId,
    required this.orderId,
    required this.tradeIndex,
    required this.status,
  });

  factory RestoreDisputeInfo.fromJson(Map<String, dynamic> json) {
    return RestoreDisputeInfo(
      disputeId: json['dispute_id'] as String,
      orderId: json['order_id'] as String,
      tradeIndex: json['trade_index'] as int,
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dispute_id': disputeId,
      'order_id': orderId,
      'trade_index': tradeIndex,
      'status': status,
    };
  }
}

class RestoreData implements Payload {
  final List<RestoreOrderInfo> orders;
  final List<RestoreDisputeInfo> disputes;

  RestoreData({
    required this.orders,
    required this.disputes,
  });

  factory RestoreData.fromJson(Map<String, dynamic> json) {
    final restoreData = json['restore_data'] as Map<String, dynamic>;
    final ordersJson = restoreData['orders'] as List<dynamic>? ?? [];
    final disputesJson = restoreData['disputes'] as List<dynamic>? ?? [];

    return RestoreData(
      orders: ordersJson
          .map((order) => RestoreOrderInfo.fromJson(order as Map<String, dynamic>))
          .toList(),
      disputes: disputesJson
          .map((dispute) => RestoreDisputeInfo.fromJson(dispute as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  String get type => 'restore_data';

  @override
  Map<String, dynamic> toJson() {
    return {
      'restore_data': {
        'orders': orders.map((o) => o.toJson()).toList(),
        'disputes': disputes.map((d) => d.toJson()).toList(),
      }
    };
  }
}
