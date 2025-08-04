import 'package:mostro_mobile/data/models/payload.dart';
import 'package:mostro_mobile/data/models/order.dart';

/// Represents a dispute in the Mostro system.
/// 
/// A dispute can be initiated by either buyer or seller when there's a problem
/// with an order. The dispute is identified by a unique ID and is associated
/// with a specific order.
class Dispute implements Payload {
  final String disputeId;
  final String? orderId;
  final String? status;
  final Order? order;
  final String? disputeToken;
  final String? adminPubkey;
  final DateTime? adminTookAt;

  Dispute({
    required this.disputeId,
    this.orderId,
    this.status,
    this.order,
    this.disputeToken,
    this.adminPubkey,
    this.adminTookAt,
  }) {
    if (disputeId.isEmpty) {
      throw ArgumentError('Dispute ID cannot be empty');
    }
  }

  /// Check if an admin has been assigned to this dispute
  bool get hasAdmin => adminPubkey != null && adminPubkey!.isNotEmpty;

  @override
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'dispute': disputeId,
    };

    if (orderId != null) {
      json['order_id'] = orderId;
    }

    if (status != null) {
      json['status'] = status;
    }

    if (order != null) {
      json['order'] = order!.toJson();
    }

    if (disputeToken != null) {
      json['dispute_token'] = disputeToken;
    }

    if (adminPubkey != null) {
      json['admin_pubkey'] = adminPubkey;
    }

    if (adminTookAt != null) {
      json['admin_took_at'] = adminTookAt!.millisecondsSinceEpoch;
    }

    return json;
  }

  factory Dispute.fromJson(Map<String, dynamic> json) {
    try {
      // Extract dispute ID
      final oid = json['dispute'];
      if (oid == null) {
        throw FormatException('Missing required field: dispute');
      }
      
      String disputeIdValue;
      if (oid is List) {
        if (oid.isEmpty) {
          throw FormatException('Dispute list cannot be empty');
        }
        disputeIdValue = oid[0]?.toString() ?? 
          (throw FormatException('First element of dispute list is null'));
      } else {
        disputeIdValue = oid.toString();
      }
      
      if (disputeIdValue.isEmpty) {
        throw FormatException('Dispute ID cannot be empty');
      }
      
      // Extract optional fields
      final orderId = json['order_id'] as String?;
      final status = json['status'] as String?;
      final disputeToken = json['dispute_token'] as String?;
      final adminPubkey = json['admin_pubkey'] as String?;
      
      // Extract admin_took_at timestamp
      DateTime? adminTookAt;
      if (json.containsKey('admin_took_at') && json['admin_took_at'] != null) {
        final timestamp = json['admin_took_at'];
        if (timestamp is int) {
          adminTookAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
        }
      }
      
      // Extract order if present
      Order? order;
      if (json.containsKey('order') && json['order'] != null) {
        order = Order.fromJson(json['order'] as Map<String, dynamic>);
      }
      
      return Dispute(
        disputeId: disputeIdValue,
        orderId: orderId,
        status: status,
        order: order,
        disputeToken: disputeToken,
        adminPubkey: adminPubkey,
        adminTookAt: adminTookAt,
      );
    } catch (e) {
      throw FormatException('Failed to parse Dispute from JSON: $e');
    }
  }

  /// Creates a copy of this Dispute with the given fields replaced with the new values.
  Dispute copyWith({
    String? disputeId,
    String? orderId,
    String? status,
    Order? order,
    String? disputeToken,
    String? adminPubkey,
    DateTime? adminTookAt,
  }) {
    return Dispute(
      disputeId: disputeId ?? this.disputeId,
      orderId: orderId ?? this.orderId,
      status: status ?? this.status,
      order: order ?? this.order,
      disputeToken: disputeToken ?? this.disputeToken,
      adminPubkey: adminPubkey ?? this.adminPubkey,
      adminTookAt: adminTookAt ?? this.adminTookAt,
    );
  }

  @override
  String get type => 'dispute';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Dispute && 
           other.disputeId == disputeId &&
           other.orderId == orderId &&
           other.status == status &&
           other.order == order &&
           other.disputeToken == disputeToken &&
           other.adminPubkey == adminPubkey &&
           other.adminTookAt == adminTookAt;
  }
  
  @override
  int get hashCode => Object.hash(disputeId, orderId, status, order, disputeToken, adminPubkey, adminTookAt);
  
  @override
  String toString() => 'Dispute(disputeId: $disputeId, orderId: $orderId, status: $status, disputeToken: $disputeToken, adminPubkey: $adminPubkey, adminTookAt: $adminTookAt)';
}
