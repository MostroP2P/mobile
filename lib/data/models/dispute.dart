import 'package:mostro_mobile/data/models/payload.dart';
import 'package:mostro_mobile/data/models/order.dart';

/// Enum representing semantic keys for dispute descriptions
/// These keys will be used for localization in the UI
enum DisputeDescriptionKey {
  initiatedByUser,      // You opened this dispute
  initiatedByPeer,      // A dispute was opened against you
  inProgress,           // Dispute is being reviewed by an admin
  resolved,             // Dispute has been resolved
  sellerRefunded,       // Dispute resolved - seller refunded
  unknown               // Unknown status
}

/// Enum representing the user's role in a dispute
enum UserRole {
  buyer,
  seller,
  unknown
}

/// Semantic keys for missing or unknown values
class DisputeSemanticKeys {
  static const String unknownOrderId = 'unknownOrderId';
  static const String unknownCounterparty = 'unknownCounterparty';
}

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

  /// Extract tag value from a Nostr event
  /// Returns the value of the tag with the given name, or null if not found
  static String? _extractTag(dynamic event, String name) {
    try {
      final tags = event.tags ?? const <List<dynamic>>[];
      final tag = tags.firstWhere(
        (tag) => tag.isNotEmpty && tag[0] == name,
        orElse: () => [],
      );
      
      if (tag.length > 1 && tag[1] != null && tag[1].toString().isNotEmpty) {
        return tag[1].toString();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Extract created_at timestamp from a Nostr event and convert to milliseconds
  /// Handles both seconds and milliseconds formats
  static int _extractCreatedAtMillis(dynamic event) {
    try {
      final createdAtRaw = event.createdAt;
      
      if (createdAtRaw == null) {
        return DateTime.now().millisecondsSinceEpoch;
      } else if (createdAtRaw is int) {
        // Nostr timestamps are in seconds, convert to milliseconds if needed
        return createdAtRaw < 10000000000 
            ? createdAtRaw * 1000 // Convert seconds to milliseconds
            : createdAtRaw;       // Already in milliseconds
      } else if (createdAtRaw is DateTime) {
        return createdAtRaw.millisecondsSinceEpoch;
      }
      return DateTime.now().millisecondsSinceEpoch;
    } catch (e) {
      return DateTime.now().millisecondsSinceEpoch;
    }
  }

  /// Create Dispute from NostrEvent and parsed content
  factory Dispute.fromNostrEvent(dynamic event, Map<String, dynamic> content) {
    try {
      // Extract dispute ID from 'd' tag, fallback to content or event ID
      final disputeId = _extractTag(event, 'd') ?? 
                        content['dispute_id'] ?? 
                        content['dispute'] ?? 
                        event.id ?? 
                        '';
      
      // Extract order ID from content
      final orderId = content['order_id'] as String?;
      
      // Extract status from 's' tag or content, default to 'initiated'
      final status = _extractTag(event, 's') ?? 
                     content['status'] as String? ?? 
                     'initiated';
      
      // Extract creation timestamp from event
      final createdAt = DateTime.fromMillisecondsSinceEpoch(
        _extractCreatedAtMillis(event)
      );
      
      return Dispute(
        disputeId: disputeId,
        orderId: orderId,
        status: status,
        adminPubkey: content['admin_pubkey'] as String?,
        createdAt: createdAt,
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
  final String? orderId;
  final String status;
  final DisputeDescriptionKey descriptionKey;
  final String? counterparty;
  final bool isCreator;
  final DateTime createdAt;
  final UserRole userRole;

  DisputeData({
    required this.disputeId,
    this.orderId,
    required this.status,
    required this.descriptionKey,
    this.counterparty,
    required this.isCreator,
    required this.createdAt,
    required this.userRole,
  });

  /// Create DisputeData from Dispute object with OrderState context
  factory DisputeData.fromDispute(Dispute dispute, {dynamic orderState}) {
    // Determine if user is the creator based on the OrderState action if available
    bool isUserCreator = false;
    
    if (orderState != null && orderState.action != null) {
      // Use OrderState action which has the correct dispute initiation info
      final actionString = orderState.action.toString();
      isUserCreator = actionString == 'dispute-initiated-by-you';
    } else if (dispute.action != null) {
      // Fallback to dispute action - this should now be set correctly
      isUserCreator = dispute.action == 'dispute-initiated-by-you';
    } else {
      // If no action info, check if this is a resolved dispute
      // For resolved disputes, we need to be more careful about determining creator
      if (dispute.status?.toLowerCase() == 'resolved' || dispute.status?.toLowerCase() == 'solved') {
        // For resolved disputes, if we can't determine creator, assume user created it
        // since they're viewing their own dispute list
        isUserCreator = true;
      } else {
        // If no action info, assume user is creator (since they can see the dispute)
        isUserCreator = true;
      }
    }
    
    // Try to get counterparty info from order state and determine correct role
    String? counterpartyName;
    UserRole userRole = UserRole.unknown;
    
    if (orderState != null) {
      // Get the counterparty nym using the same approach as chat
      if (orderState.peer != null) {
        counterpartyName = orderState.peer!.publicKey; // This will be resolved by nickNameProvider in the UI
      }
    } else if (dispute.adminPubkey != null && dispute.status != 'resolved') {
      // Only use admin pubkey as counterparty if dispute is not resolved and no peer info
      // For resolved disputes, we don't want to show admin as counterparty
      counterpartyName = dispute.adminPubkey;
    }
      
    // Determine if user is buyer or seller based on order type
    if (orderState != null && orderState.order != null) {
      // If order type is 'buy', then the order creator is buying (user is buyer)
      // If order type is 'sell', then the order creator is selling (user is seller)
      // The peer is always the opposite role
      userRole = orderState.order!.kind.value == 'buy' ? UserRole.buyer : UserRole.seller;
    }

    // Get the appropriate description key based on status and creator
    final descriptionKey = _getDescriptionKeyForStatus(dispute.status ?? 'unknown', isUserCreator);

    return DisputeData(
      disputeId: dispute.disputeId,
      orderId: dispute.orderId, // No fallback to hardcoded string
      status: dispute.status ?? 'unknown',
      descriptionKey: descriptionKey,
      counterparty: counterpartyName,
      isCreator: isUserCreator,
      createdAt: dispute.createdAt ?? DateTime.now(),
      userRole: userRole,
    );
  }

  /// Create DisputeData from DisputeEvent (legacy method)
  factory DisputeData.fromDisputeEvent(dynamic disputeEvent, {String? userAction}) {
    // Determine if user is the creator based on the action or other indicators
    bool isUserCreator = _determineIfUserIsCreator(disputeEvent, userAction);
    
    // Get the appropriate description key based on status and creator
    final descriptionKey = _getDescriptionKeyForStatus(disputeEvent.status, isUserCreator);
    
    return DisputeData(
      disputeId: disputeEvent.disputeId,
      orderId: disputeEvent.orderId, // No fallback to hardcoded string
      status: disputeEvent.status,
      descriptionKey: descriptionKey,
      counterparty: null, // Would need to fetch from order data
      isCreator: isUserCreator,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        disputeEvent.createdAt is int 
          ? disputeEvent.createdAt * 1000 
          : DateTime.now().millisecondsSinceEpoch
      ),
      userRole: UserRole.unknown, // Default value for legacy method
    );
  }

  /// Determine if the user is the creator of the dispute
  static bool _determineIfUserIsCreator(dynamic disputeEvent, String? userAction) {
    // If we have userAction information, use it to determine creator
    if (userAction != null) {
      return userAction == 'dispute-initiated-by-you';
    }
    
    // Otherwise, try to determine from the event itself
    // This is a fallback and may not be accurate
    return true; // Default to true for now
  }

  /// Get a description key for the dispute status
  static DisputeDescriptionKey _getDescriptionKeyForStatus(String status, bool isUserCreator) {
    switch (status.toLowerCase()) {
      case 'initiated':
        return isUserCreator 
          ? DisputeDescriptionKey.initiatedByUser 
          : DisputeDescriptionKey.initiatedByPeer;
      case 'in-progress':
        return DisputeDescriptionKey.inProgress;
      case 'resolved':
      case 'solved':
        return DisputeDescriptionKey.resolved;
      case 'seller-refunded':
        return DisputeDescriptionKey.sellerRefunded;
      default:
        return DisputeDescriptionKey.unknown;
    }
  }
  
  /// Backward compatibility getter for description
  String get description {
    switch (descriptionKey) {
      case DisputeDescriptionKey.initiatedByUser:
        return 'You opened this dispute';
      case DisputeDescriptionKey.initiatedByPeer:
        return 'A dispute was opened against you';
      case DisputeDescriptionKey.inProgress:
        return 'Dispute is being reviewed by an admin';
      case DisputeDescriptionKey.resolved:
        return 'Dispute has been resolved';
      case DisputeDescriptionKey.sellerRefunded:
        return 'Dispute resolved - seller refunded';
      case DisputeDescriptionKey.unknown:
        return 'Unknown status';
    }
  }
  
  /// Backward compatibility getter for userIsBuyer
  bool get userIsBuyer => userRole == UserRole.buyer;
  
  /// Convenience getter for orderId with fallback
  String get orderIdDisplay => orderId ?? DisputeSemanticKeys.unknownOrderId;
  
  /// Convenience getter for counterparty with fallback
  String get counterpartyDisplay => counterparty ?? DisputeSemanticKeys.unknownCounterparty;
}
