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
    final orderId = json['order_id'];
    if (orderId == null || orderId is! String) {
      throw FormatException(
        'Invalid or missing order_id: expected String, got ${orderId.runtimeType}'
      );
    }

    final tradeIndexValue = json['trade_index'];
    if (tradeIndexValue == null) {
      throw FormatException('Missing required field: trade_index');
    }

    final int tradeIndex;
    if (tradeIndexValue is int) {
      tradeIndex = tradeIndexValue;
    } else if (tradeIndexValue is String) {
      final parsed = int.tryParse(tradeIndexValue);
      if (parsed == null) {
        throw FormatException(
          'Invalid trade_index: cannot parse "$tradeIndexValue" as int'
        );
      }
      tradeIndex = parsed;
    } else {
      throw FormatException(
        'Invalid trade_index type: expected int or String, got ${tradeIndexValue.runtimeType}'
      );
    }

    final status = json['status'];
    if (status == null || status is! String) {
      throw FormatException(
        'Invalid or missing status: expected String, got ${status.runtimeType}'
      );
    }

    return RestoreOrderInfo(
      orderId: orderId,
      tradeIndex: tradeIndex,
      status: status,
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
    final disputeId = json['dispute_id'];
    if (disputeId == null || disputeId is! String) {
      throw FormatException(
        'Invalid or missing dispute_id: expected String, got ${disputeId.runtimeType}'
      );
    }

    final orderId = json['order_id'];
    if (orderId == null || orderId is! String) {
      throw FormatException(
        'Invalid or missing order_id: expected String, got ${orderId.runtimeType}'
      );
    }

    final tradeIndexValue = json['trade_index'];
    if (tradeIndexValue == null) {
      throw FormatException('Missing required field: trade_index');
    }

    final int tradeIndex;
    if (tradeIndexValue is int) {
      tradeIndex = tradeIndexValue;
    } else if (tradeIndexValue is String) {
      final parsed = int.tryParse(tradeIndexValue);
      if (parsed == null) {
        throw FormatException(
          'Invalid trade_index: cannot parse "$tradeIndexValue" as int'
        );
      }
      tradeIndex = parsed;
    } else {
      throw FormatException(
        'Invalid trade_index type: expected int or String, got ${tradeIndexValue.runtimeType}'
      );
    }

    final status = json['status'];
    if (status == null || status is! String) {
      throw FormatException(
        'Invalid or missing status: expected String, got ${status.runtimeType}'
      );
    }

    return RestoreDisputeInfo(
      disputeId: disputeId,
      orderId: orderId,
      tradeIndex: tradeIndex,
      status: status,
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
