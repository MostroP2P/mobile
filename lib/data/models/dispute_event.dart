import 'dart:convert';
import 'package:dart_nostr/dart_nostr.dart';

/// Represents a dispute event (kind 38383) with status information.
/// 
/// Dispute events are used to track the status of disputes in the Mostro system.
/// They contain tags that indicate the dispute ID, status, and other metadata.
class DisputeEvent {
  final String id;
  final String disputeId;
  final String status;
  final int createdAt;
  final String pubkey;
  final String? orderId;

  DisputeEvent({
    required this.id,
    required this.disputeId,
    required this.status,
    required this.createdAt,
    required this.pubkey,
    this.orderId,
  });

  /// Creates a DisputeEvent from a NostrEvent.
  /// 
  /// The NostrEvent must be kind 38383 and have the appropriate tags.
  factory DisputeEvent.fromEvent(NostrEvent event) {
    if (event.kind != 38383) {
      throw ArgumentError('Event must be kind 38383 for DisputeEvent');
    }

    // Extract the dispute ID from the 'd' tag
    final dTag = event.tags!.firstWhere(
      (tag) => tag.isNotEmpty && tag[0] == 'd',
      orElse: () => throw ArgumentError('Event must have a "d" tag with dispute ID'),
    );
    
    if (dTag.length < 2 || dTag[1].isEmpty) {
      throw ArgumentError('Invalid dispute ID in "d" tag');
    }
    
    // Extract the status from the 's' tag
    final sTag = event.tags!.firstWhere(
      (tag) => tag.isNotEmpty && tag[0] == 's',
      orElse: () => throw ArgumentError('Event must have an "s" tag with status'),
    );
    
    if (sTag.length < 2 || sTag[1].isEmpty) {
      throw ArgumentError('Invalid status in "s" tag');
    }

    // Verify this is a dispute event with the 'z' tag
    event.tags!.firstWhere(
      (tag) => tag.isNotEmpty && tag[0] == 'z' && tag[1] == 'dispute',
      orElse: () => throw ArgumentError('Event must have a "z" tag with value "dispute"'),
    );

    // Handle createdAt which could be int or null
    final createdAt = event.createdAt;
    final int timestamp;
    
    if (createdAt == null) {
      // Fallback to current time if createdAt is null
      timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    } else {
      // In dart_nostr package, createdAt should be an int, but we cast it to be safe
      timestamp = createdAt as int;
    }
    
    // Extract order ID from event content
    String? orderId = _extractOrderIdFromContent(event.content);
    
    return DisputeEvent(
      id: event.id!,
      disputeId: dTag[1],
      status: sTag[1],
      createdAt: timestamp,
      pubkey: event.pubkey,
      orderId: orderId,
    );
  }

  /// Extract order ID from event content
  /// Based on Mostro event structure: {"order":{"id":"order-id",...}}
  static String? _extractOrderIdFromContent(String? content) {
    if (content == null || content.isEmpty) {
      return null;
    }
    
    try {
      final Map<String, dynamic> parsed = jsonDecode(content);
      final order = parsed['order'] as Map<String, dynamic>?;
      return order?['id'] as String?;
    } catch (e) {
      // If parsing fails, return null
      return null;
    }
  }

  /// Checks if the event is from the specified Mostro pubkey.
  bool isFromMostro(String mostroPubkey) {
    return pubkey == mostroPubkey;
  }

  @override
  String toString() {
    return 'DisputeEvent(id: $id, disputeId: $disputeId, status: $status, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DisputeEvent &&
        other.id == id &&
        other.disputeId == disputeId &&
        other.status == status &&
        other.createdAt == createdAt &&
        other.pubkey == pubkey &&
        other.orderId == orderId;
  }

  @override
  int get hashCode => Object.hash(id, disputeId, status, createdAt, pubkey, orderId);
}
