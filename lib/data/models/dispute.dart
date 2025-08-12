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
      String? disputeTokenValue;
      
      if (oid is List) {
        if (oid.isEmpty) {
          throw FormatException('Dispute list cannot be empty');
        }
        disputeIdValue = oid[0]?.toString() ?? 
          (throw FormatException('First element of dispute list is null'));
        
        // Extract token from array: [disputeId, userToken, peerToken]
        // Index 1 is the user's token (who initiated the dispute)
        if (oid.length > 1 && oid[1] != null) {
          disputeTokenValue = oid[1].toString();
        }
      } else {
        disputeIdValue = oid.toString();
      }
      
      if (disputeIdValue.isEmpty) {
        throw FormatException('Dispute ID cannot be empty');
      }
      
      // Extract optional fields
      final orderId = json['order_id'] as String?;
      final status = json['status'] as String?;
      // Use token from array if available, otherwise fallback to json field
      final disputeToken = disputeTokenValue ?? json['dispute_token'] as String?;
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

/// UI-facing view model for disputes used across widgets.
class DisputeData {
  final String disputeId;
  final String orderId;
  final String status;
  final String description;
  final String counterparty;
  final bool isCreator;
  final DateTime createdAt;

  DisputeData({
    required this.disputeId,
    required this.orderId,
    required this.status,
    required this.description,
    required this.counterparty,
    required this.isCreator,
    required this.createdAt,
  });

  /// Create DisputeData from DisputeEvent
  factory DisputeData.fromDisputeEvent(dynamic disputeEvent) {
    // For now, we'll create basic data from the dispute event
    // In a full implementation, this would combine data from multiple sources
    return DisputeData(
      disputeId: disputeEvent.disputeId,
      orderId: disputeEvent.disputeId, // Placeholder - would need order mapping
      status: disputeEvent.status,
      description: _getDescriptionForStatus(disputeEvent.status),
      counterparty: 'Unknown', // Would need to fetch from order data
      isCreator: true, // Assume user is creator for now
      createdAt: DateTime.fromMillisecondsSinceEpoch(disputeEvent.createdAt * 1000),
    );
  }

  static String _getDescriptionForStatus(String status) {
    switch (status.toLowerCase()) {
      case 'initiated':
        return 'You opened this dispute';
      case 'in-progress':
        return 'Dispute is being reviewed by an admin';
      case 'settled':
        return 'Dispute has been resolved';
      case 'seller-refunded':
        return 'Dispute resolved - seller refunded';
      default:
        return 'Dispute status: $status';
    }
  }
}
