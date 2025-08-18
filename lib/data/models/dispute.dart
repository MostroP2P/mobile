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
  final DateTime? createdAt;
  final String? action;

  Dispute({
    required this.disputeId,
    this.orderId,
    this.status,
    this.order,
    this.disputeToken,
    this.adminPubkey,
    this.adminTookAt,
    this.createdAt,
    this.action,
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

    if (createdAt != null) {
      json['created_at'] = createdAt!.millisecondsSinceEpoch;
    }

    if (action != null) {
      json['action'] = action;
    }

    return json;
  }

  /// Create Dispute from NostrEvent and parsed content
  factory Dispute.fromNostrEvent(dynamic event, Map<String, dynamic> content) {
    try {
      // Extract dispute data from the event content
      final disputeId = content['dispute_id'] ?? event.id ?? '';
      final orderId = content['order_id'] as String?;
      final status = content['status'] as String? ?? 'initiated';
      
      return Dispute(
        disputeId: disputeId,
        orderId: orderId,
        status: status,
        adminPubkey: content['admin_pubkey'] as String?,
        createdAt: DateTime.now(), // Default to current time for events
        action: content['action'] as String?,
      );
    } catch (e) {
      throw FormatException('Failed to parse Dispute from NostrEvent: $e');
    }
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
      
      // Extract created_at timestamp
      DateTime? createdAt;
      if (json.containsKey('created_at') && json['created_at'] != null) {
        final timestamp = json['created_at'];
        if (timestamp is int) {
          createdAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
        }
      }
      
      return Dispute(
        disputeId: disputeIdValue,
        orderId: orderId,
        status: status,
        order: order,
        disputeToken: disputeToken,
        adminPubkey: adminPubkey,
        adminTookAt: adminTookAt,
        createdAt: createdAt,
        action: json['action'] as String?,
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
    DateTime? createdAt,
    String? action,
  }) {
    return Dispute(
      disputeId: disputeId ?? this.disputeId,
      orderId: orderId ?? this.orderId,
      status: status ?? this.status,
      order: order ?? this.order,
      disputeToken: disputeToken ?? this.disputeToken,
      adminPubkey: adminPubkey ?? this.adminPubkey,
      adminTookAt: adminTookAt ?? this.adminTookAt,
      createdAt: createdAt ?? this.createdAt,
      action: action ?? this.action,
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
           other.adminTookAt == adminTookAt &&
           other.createdAt == createdAt &&
           other.action == action;
  }
  
  @override
  int get hashCode => Object.hash(disputeId, orderId, status, order, disputeToken, adminPubkey, adminTookAt, createdAt, action);
  
  @override
  String toString() => 'Dispute(disputeId: $disputeId, orderId: $orderId, status: $status, disputeToken: $disputeToken, adminPubkey: $adminPubkey, adminTookAt: $adminTookAt, createdAt: $createdAt, action: $action)';
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

  /// Create DisputeData from Dispute object with OrderState context
  factory DisputeData.fromDispute(Dispute dispute, {dynamic orderState}) {
    // Determine if user is the creator based on the OrderState action if available
    bool isUserCreator = false;
    
    print('🔍 DisputeData.fromDispute DEBUG:');
    print('   disputeId: ${dispute.disputeId}');
    print('   orderId: ${dispute.orderId}');
    print('   dispute.action: ${dispute.action}');
    print('   orderState: $orderState');
    print('   orderState?.action: ${orderState?.action}');
    print('   orderState?.action.toString(): ${orderState?.action.toString()}');
    
    if (orderState != null && orderState.action != null) {
      // Use OrderState action which has the correct dispute initiation info
      final actionString = orderState.action.toString();
      isUserCreator = actionString == 'dispute-initiated-by-you';
      print('   Using OrderState action: $actionString → isUserCreator: $isUserCreator');
    } else if (dispute.action != null) {
      // Fallback to dispute action
      isUserCreator = dispute.action == 'dispute-initiated-by-you';
      print('   Using dispute action: ${dispute.action} → isUserCreator: $isUserCreator');
    } else {
      print('   No action available, defaulting to false');
    }
    
    print('   Final isUserCreator: $isUserCreator');
    
    return DisputeData(
      disputeId: dispute.disputeId,
      orderId: dispute.orderId ?? dispute.disputeId, // Use orderId if available, fallback to disputeId
      status: dispute.status ?? 'unknown',
      description: _getDescriptionForStatus(dispute.status ?? 'unknown', isUserCreator),
      counterparty: 'Unknown', // Would need to fetch from order data
      isCreator: isUserCreator,
      createdAt: dispute.createdAt ?? DateTime.now(),
    );
  }

  /// Create DisputeData from DisputeEvent (legacy method)
  factory DisputeData.fromDisputeEvent(dynamic disputeEvent, {String? userAction}) {
    // Determine if user is the creator based on the action or other indicators
    bool isUserCreator = _determineIfUserIsCreator(disputeEvent, userAction);
    
    return DisputeData(
      disputeId: disputeEvent.disputeId,
      orderId: disputeEvent.orderId ?? disputeEvent.disputeId, // Use orderId if available, fallback to disputeId
      status: disputeEvent.status,
      description: _getDescriptionForStatus(disputeEvent.status, isUserCreator),
      counterparty: 'Unknown', // Would need to fetch from order data
      isCreator: isUserCreator,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        disputeEvent.createdAt is int 
          ? disputeEvent.createdAt * 1000 
          : DateTime.now().millisecondsSinceEpoch
      ),
    );
  }

  /// Determine if the user is the creator of the dispute
  static bool _determineIfUserIsCreator(dynamic disputeEvent, String? userAction) {
    // If we have userAction information, use it to determine creator
    if (userAction != null) {
      return userAction == 'dispute-initiated-by-you';
    }
    
    // Fallback: try to infer from dispute event properties
    // This is a simplified approach - in practice, you might need more context
    // from the order data or session information
    return false; // Conservative default - assume user received the dispute
  }

  static String _getDescriptionForStatus(String status, bool isUserCreator) {
    switch (status.toLowerCase()) {
      case 'initiated':
        return isUserCreator 
          ? 'You opened this dispute' 
          : 'A dispute was opened against you';
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
