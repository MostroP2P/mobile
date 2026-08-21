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
    final tradeIndex = json['trade_index'] as int;
    // Index 0 is the identity key, so a restore response naming it would have
    // the session that gets built here sign and ECDH under the master
    // identity. Rejected at the boundary rather than at derivation, so the
    // order never becomes a session in the first place.
    if (tradeIndex < 1) {
      throw FormatException('Trade index must be greater than 0: $tradeIndex');
    }

    return RestoredOrder(
      id: json['order_id'] as String,
      tradeIndex: tradeIndex,
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'order_id': id,
    'trade_index': tradeIndex,
    'status': status,
  };
}

class RestoredDispute {
  final String disputeId;
  final String orderId;
  final int tradeIndex;
  final String status;
  final String? initiator;
  final String? solverPubkey;

  RestoredDispute({
    required this.disputeId,
    required this.orderId,
    required this.tradeIndex,
    required this.status,
    this.initiator,
    this.solverPubkey,
  });

  factory RestoredDispute.fromJson(Map<String, dynamic> json) {
    final rawInitiator = json['initiator'] as String?;
    final normalizedInitiator = _normalizeInitiator(rawInitiator);

    final tradeIndex = json['trade_index'] as int;
    if (tradeIndex < 1) {
      throw FormatException('Trade index must be greater than 0: $tradeIndex');
    }

    return RestoredDispute(
      disputeId: json['dispute_id'] as String,
      orderId: json['order_id'] as String,
      tradeIndex: tradeIndex,
      status: json['status'] as String,
      initiator: normalizedInitiator,
      solverPubkey: json['solver_pubkey'] as String?,
    );
  }

  static String? _normalizeInitiator(String? value) {
    if (value == null) return null;

    final normalized = value.trim().toLowerCase();
    if (normalized == 'buyer' || normalized == 'seller') {
      return normalized;
    }

    return null;
  }

  Map<String, dynamic> toJson() => {
    'dispute_id': disputeId,
    'order_id': orderId,
    'trade_index': tradeIndex,
    'status': status,
    if (initiator != null) 'initiator': initiator,
    if (solverPubkey != null) 'solver_pubkey': solverPubkey,
  };
}
