import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mostro_mobile/data/enums.dart' as enums;
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/payload.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';
import 'package:mostro_mobile/generated/l10n.dart';

/// Enum representing semantic keys for dispute descriptions
/// These keys will be used for localization in the UI
enum DisputeDescriptionKey {
  initiatedByUser,      // You opened this dispute
  initiatedByPeer,      // A dispute was opened against you
  initiatedPendingAdmin,// Dispute initiated, waiting for admin assignment
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
  static const _sentinel = Object();
  final String disputeId;
  final String? orderId;
  final String? status;
  final Order? order;
  final String? adminPubkey;
  final DateTime? adminTookAt;
  final DateTime? createdAt;
  final String? action;

  Dispute({
    required this.disputeId,
    this.orderId,
    this.status,
    this.order,
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
      final adminPubkey = json['admin_pubkey'] as String?;
      
      // Extract admin_took_at timestamp
      DateTime? adminTookAt;
      if (json.containsKey('admin_took_at') && json['admin_took_at'] != null) {
        final timestamp = json['admin_took_at'];
        if (timestamp is int || timestamp is double) {
          final timestampInt = timestamp is double ? timestamp.toInt() : timestamp as int;
          final normalizedTimestamp = timestampInt < 10000000000 
              ? timestampInt * 1000 // Convert seconds to milliseconds
              : timestampInt;       // Already in milliseconds
          adminTookAt = DateTime.fromMillisecondsSinceEpoch(normalizedTimestamp);
        } else if (timestamp is String) {
          final parsed = DateTime.tryParse(timestamp);
          if (parsed != null) {
            adminTookAt = parsed;
          }
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
        if (timestamp is int || timestamp is double) {
          final timestampInt = timestamp is double ? timestamp.toInt() : timestamp as int;
          final normalizedTimestamp = timestampInt < 10000000000 
              ? timestampInt * 1000 // Convert seconds to milliseconds
              : timestampInt;       // Already in milliseconds
          createdAt = DateTime.fromMillisecondsSinceEpoch(normalizedTimestamp);
        } else if (timestamp is String) {
          final parsed = DateTime.tryParse(timestamp);
          if (parsed != null) {
            createdAt = parsed;
          }
        }
      }
      
      return Dispute(
        disputeId: disputeIdValue,
        orderId: orderId,
        status: status,
        order: order,
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
  /// Pass explicit null to clear nullable fields.
  Dispute copyWith({
    Object? disputeId = _sentinel,
    Object? orderId = _sentinel,
    Object? status = _sentinel,
    Object? order = _sentinel,
    Object? adminPubkey = _sentinel,
    Object? adminTookAt = _sentinel,
    Object? createdAt = _sentinel,
    Object? action = _sentinel,
  }) {
    return Dispute(
      disputeId: disputeId == _sentinel ? this.disputeId : disputeId as String,
      orderId: orderId == _sentinel ? this.orderId : orderId as String?,
      status: status == _sentinel ? this.status : status as String?,
      order: order == _sentinel ? this.order : order as Order?,
      adminPubkey: adminPubkey == _sentinel ? this.adminPubkey : adminPubkey as String?,
      adminTookAt: adminTookAt == _sentinel ? this.adminTookAt : adminTookAt as DateTime?,
      createdAt: createdAt == _sentinel ? this.createdAt : createdAt as DateTime?,
      action: action == _sentinel ? this.action : action as String?,
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
           other.adminPubkey == adminPubkey &&
           other.adminTookAt == adminTookAt &&
           other.createdAt == createdAt &&
           other.action == action;
  }
  
  @override
  int get hashCode => Object.hash(disputeId, orderId, status, order, adminPubkey, adminTookAt, createdAt, action);
  
  @override
  String toString() => 'Dispute(disputeId: $disputeId, orderId: $orderId, status: $status, adminPubkey: $adminPubkey, adminTookAt: $adminTookAt, createdAt: $createdAt, action: $action)';
}

/// UI-facing view model for disputes used across widgets.
class DisputeData {
  final String disputeId;
  final String? orderId;
  final String status;
  final DisputeDescriptionKey descriptionKey;
  final String? counterparty;
  final bool? isCreator;
  final DateTime createdAt;
  final UserRole userRole;
  final String? action; // Store the action that resolved the dispute

  DisputeData({
    required this.disputeId,
    this.orderId,
    required this.status,
    required this.descriptionKey,
    this.counterparty,
    this.isCreator,
    required this.createdAt,
    required this.userRole,
    this.action,
  });

  /// Create DisputeData from Dispute object with OrderState context
  /// 
  /// [userRole] is the user's role in the order (buyer or seller), obtained from the Session
  factory DisputeData.fromDispute(
    Dispute dispute, {
    OrderState? orderState,
    UserRole? userRole,
  }) {
    // Determine if user is the creator based on the OrderState action if available
    bool? isUserCreator;
    
    if (orderState != null) {
      // Use OrderState action which has the correct dispute initiation info
      if (kDebugMode) {
        debugPrint('DisputeData.fromDispute: orderState.action = ${orderState.action}');
      }
      isUserCreator = orderState.action == enums.Action.disputeInitiatedByYou;
    } else if (dispute.action != null) {
      // Fallback to dispute action - convert string to enum for comparison
      if (kDebugMode) {
        debugPrint('DisputeData.fromDispute: dispute.action = "${dispute.action}"');
      }
      // Parse the action string to enum for proper comparison
      final disputeAction = _parseActionFromString(dispute.action!);
      isUserCreator = disputeAction == enums.Action.disputeInitiatedByYou;
    } else {
      // If no action info is available, leave as null (unknown state)
      // This removes the assumption that user is creator by default
      if (kDebugMode) {
        debugPrint('DisputeData.fromDispute: No action info available, setting isUserCreator = null');
      }
      isUserCreator = null;
    }
    
    // Try to get counterparty info from order state
    String? counterpartyName;
    
    // Use the provided userRole or default to unknown
    final finalUserRole = userRole ?? UserRole.unknown;

    // Terminal dispute states where admin should not be used as counterparty
    // Terminal statuses where the dispute is finished and admin should not be shown as counterparty
    final terminalStatusList = [
      'resolved',
      'closed',
      'seller-refunded',
      'seller_refunded',
      'admin-canceled',
      'admin_canceled',
      'admin-settled',
      'admin_settled',
      'solved',
      'completed',
    ];

    if (orderState?.peer != null) {
      counterpartyName = orderState!.peer!.publicKey; // This will be resolved by nickNameProvider in the UI
    }

    // Only use admin pubkey as counterparty if:
    // 1. There is no peer information available
    // 2. Admin pubkey exists
    // 3. Dispute is not in a terminal state (normalize status to lowercase for comparison)
    final normalizedStatus = dispute.status?.toLowerCase().trim() ?? '';
    if (orderState?.peer == null && 
        dispute.adminPubkey != null && 
        !terminalStatusList.contains(normalizedStatus)) {
      counterpartyName = dispute.adminPubkey;
    }
    
    if (kDebugMode) {
      debugPrint('DisputeData.fromDispute: User role = $finalUserRole');
    }

    // Get the appropriate description key based on status and creator
    final descriptionKey = _getDescriptionKeyForStatus(
      dispute.status ?? 'unknown', 
      isUserCreator,
      hasAdmin: dispute.hasAdmin,
    );

    return DisputeData(
      disputeId: dispute.disputeId,
      orderId: dispute.orderId ?? (orderState?.order?.id), // Use order from orderState if dispute.orderId is null
      status: dispute.status ?? 'initiated',
      descriptionKey: descriptionKey,
      counterparty: counterpartyName,
      isCreator: isUserCreator,
      createdAt: dispute.createdAt ?? DateTime.now(),
      userRole: finalUserRole,
      action: dispute.action, // Pass the action to determine resolution type
    );
  }

  /// Create DisputeData from DisputeEvent (legacy method)
  factory DisputeData.fromDisputeEvent(dynamic disputeEvent, {String? userAction}) {
    // Determine if user is the creator based on the action or other indicators
    bool? isUserCreator = _determineIfUserIsCreator(disputeEvent, userAction);
    
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
          ? (disputeEvent.createdAt <= 9999999999 
              ? disputeEvent.createdAt * 1000  // Convert seconds to milliseconds
              : disputeEvent.createdAt)        // Already in milliseconds
          : DateTime.now().millisecondsSinceEpoch
      ),
      userRole: UserRole.unknown, // Default value for legacy method
      action: null, // Legacy method doesn't have action info
    );
  }

  /// Determine if the user is the creator of the dispute
  static bool? _determineIfUserIsCreator(dynamic disputeEvent, String? userAction) {
    // If we have userAction information, use it to determine creator
    if (userAction != null) {
      return userAction == 'dispute-initiated-by-you';
    }
    
    // Otherwise, return null for unknown state instead of assuming
    // This removes the fallback assumption that user is creator
    return null;
  }

  /// Get a description key for the dispute status
  static DisputeDescriptionKey _getDescriptionKeyForStatus(String status, bool? isUserCreator, {bool hasAdmin = false}) {
    if (kDebugMode) {
      debugPrint('_getDescriptionKeyForStatus: status="$status", isUserCreator=$isUserCreator, hasAdmin=$hasAdmin');
    }
    switch (status.toLowerCase()) {
      case 'initiated':
        // If admin has been assigned, it's in progress even if status says initiated
        if (hasAdmin) {
          if (kDebugMode) {
            debugPrint('_getDescriptionKeyForStatus: returning inProgress (hasAdmin=true)');
          }
          return DisputeDescriptionKey.inProgress;
        }
        // For 'initiated' status, always show "admin will take this dispute soon"
        // regardless of who created it, since the key info is that it's waiting for admin
        if (kDebugMode) {
          debugPrint('_getDescriptionKeyForStatus: returning initiatedPendingAdmin (status=initiated, waiting for admin)');
        }
        return isUserCreator == true
          ? DisputeDescriptionKey.initiatedByUser
          : DisputeDescriptionKey.initiatedPendingAdmin;

      case 'in-progress':
        return DisputeDescriptionKey.inProgress;
      case 'resolved':
      case 'solved':
      case 'closed':
        return DisputeDescriptionKey.resolved;
      case 'seller-refunded':
        return DisputeDescriptionKey.sellerRefunded;
      default:
        if (kDebugMode) {
          debugPrint('_getDescriptionKeyForStatus: returning UNKNOWN for status="$status"');
        }
        return DisputeDescriptionKey.unknown;
    }
  }
  
  /// Get localized description message
  String getLocalizedDescription(BuildContext context) {
    final l10n = S.of(context)!;
    switch (descriptionKey) {
      case DisputeDescriptionKey.initiatedByUser:
        return l10n.disputeDescriptionInitiatedByUser;
      case DisputeDescriptionKey.initiatedByPeer:

        return l10n.disputeDescriptionInitiatedByPeer;
      case DisputeDescriptionKey.initiatedPendingAdmin:
        return l10n.disputeDescriptionInitiatedPendingAdmin;

      case DisputeDescriptionKey.inProgress:
        return l10n.disputeDescriptionInProgress;
      case DisputeDescriptionKey.resolved:
        if (action == 'user-completed') {
          return l10n.disputeClosedUserCompleted;
        } else if (action == 'cooperative-cancel') {
          return l10n.disputeClosedCooperativeCancel;
        }
        return l10n.disputeDescriptionResolved;
      case DisputeDescriptionKey.sellerRefunded:
        return l10n.disputeDescriptionSellerRefunded;
      case DisputeDescriptionKey.unknown:
        return l10n.disputeDescriptionUnknown;
    }
  }

  
  /// Backward compatibility getter for userIsBuyer
  bool get userIsBuyer => userRole == UserRole.buyer;
  
  /// Convenience getter for orderId with fallback
  String get orderIdDisplay => orderId ?? DisputeSemanticKeys.unknownOrderId;
  
  /// Convenience getter for counterparty with fallback
  String get counterpartyDisplay => counterparty ?? DisputeSemanticKeys.unknownCounterparty;
  
  /// Parse action string to Action enum
  /// This handles the conversion from stored string actions to enum values
  static enums.Action? _parseActionFromString(String actionString) {
    // Map common action strings to enum values
    switch (actionString.toLowerCase()) {
      case 'dispute-initiated-by-you':
        return enums.Action.disputeInitiatedByYou;
      case 'dispute-initiated-by-peer':
        return enums.Action.disputeInitiatedByPeer;
      case 'admin-took-dispute':
        return enums.Action.adminTookDispute;
      case 'admin-settled':
        return enums.Action.adminSettled;
      default:
        if (kDebugMode) {
          debugPrint('_parseActionFromString: Unknown action string "$actionString"');
        }
        return null;
    }
  }
}
