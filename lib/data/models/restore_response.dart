import 'package:mostro_mobile/data/models/payload.dart';

class RestoreData implements Payload {
  final List<RestoredOrder> orders;
  final List<RestoredDispute> disputes;

  RestoreData({
    required this.orders,
    required this.disputes,
  });

  @override
  String get type => 'restore_data';

  factory RestoreData.fromJson(Map<String, dynamic> json) {
    final restoreData = json['restore_data'] as Map<String, dynamic>;

    return RestoreData(
      orders: (restoreData['orders'] as List<dynamic>?)
          ?.map((o) => RestoredOrder.fromJson(o as Map<String, dynamic>))
          .toList() ?? [],
      disputes: (restoreData['disputes'] as List<dynamic>?)
          ?.map((d) => RestoredDispute.fromJson(d as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'restore_data': {
      'orders': orders.map((o) => o.toJson()).toList(),
      'disputes': disputes.map((d) => d.toJson()).toList(),
    }
  };
}

class RestoredOrder {
  final String id;
  final int tradeIndex;
  final String status;

  RestoredOrder({
    required this.id,
    required this.tradeIndex,
    required this.status,
  });

  factory RestoredOrder.fromJson(Map<String, dynamic> json) {
    return RestoredOrder(
      id: json['order_id'] as String,
      tradeIndex: json['trade_index'] as int,
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'trade_index': tradeIndex,
    'status': status,
  };
}

class RestoredDispute {
  final String disputeId;
  final String orderId;
  final int tradeIndex;
  final String status;

  RestoredDispute({
    required this.disputeId,
    required this.orderId,
    required this.tradeIndex,
    required this.status,
  });

  factory RestoredDispute.fromJson(Map<String, dynamic> json) {
    return RestoredDispute(
      disputeId: json['dispute_id'] as String,
      orderId: json['order_id'] as String,
      tradeIndex: json['trade_index'] as int,
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'dispute_id': disputeId,
    'order_id': orderId,
    'trade_index': tradeIndex,
    'status': status,
  };
}