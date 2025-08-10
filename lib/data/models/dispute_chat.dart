import 'package:dart_nostr/dart_nostr.dart';

/// Represents a dispute-specific chat session between user and admin/solver
class DisputeChat {
  final String disputeId;
  final String adminPubkey;
  final String userPubkey;
  final String? disputeToken;
  final List<NostrEvent> messages;
  final DateTime? createdAt;
  final DateTime? lastMessageAt;

  DisputeChat({
    required this.disputeId,
    required this.adminPubkey,
    required this.userPubkey,
    this.disputeToken,
    required this.messages,
    this.createdAt,
    this.lastMessageAt,
  });

  /// Check if the dispute token has been verified by the admin
  /// This is done by checking if the first message from admin contains the token
  bool get isTokenVerified {
    if (disputeToken == null || disputeToken!.isEmpty) return true;
    
    // Find the first message from admin
    final firstAdminMessage = messages
        .where((msg) => msg.pubkey == adminPubkey)
        .fold<NostrEvent?>(null, (earliest, current) {
      if (earliest == null) return current;
      final earliestTime = earliest.createdAt;
      final currentTime = current.createdAt;
      if (earliestTime == null) return current;
      if (currentTime == null) return earliest;
      return currentTime.isBefore(earliestTime) ? current : earliest;
    });
    
    if (firstAdminMessage == null) return false;
    
    // Check if the message content contains the dispute token
    return firstAdminMessage.content?.contains(disputeToken!) ?? false;
  }

  /// Get the last message in the chat
  NostrEvent? get lastMessage {
    if (messages.isEmpty) return null;
    
    return messages.reduce((a, b) {
      final aTime = a.createdAt;
      final bTime = b.createdAt;
      if (aTime == null) return b;
      if (bTime == null) return a;
      return aTime.isAfter(bTime) ? a : b;
    });
  }

  /// Get messages sorted by creation time (oldest first)
  List<NostrEvent> get sortedMessages {
    final sorted = List<NostrEvent>.from(messages);
    sorted.sort((a, b) {
      final aTime = a.createdAt;
      final bTime = b.createdAt;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return -1;
      if (bTime == null) return 1;
      return aTime.compareTo(bTime);
    });
    return sorted;
  }

  /// Add a new message to the chat
  DisputeChat addMessage(NostrEvent message) {
    final updatedMessages = [...messages, message];
    final messageTime = message.createdAt;
    final newLastMessageAt = messageTime;
    
    return copyWith(
      messages: updatedMessages,
      lastMessageAt: newLastMessageAt,
    );
  }

  /// Create a copy with updated fields
  DisputeChat copyWith({
    String? disputeId,
    String? adminPubkey,
    String? userPubkey,
    String? disputeToken,
    List<NostrEvent>? messages,
    DateTime? createdAt,
    DateTime? lastMessageAt,
  }) {
    return DisputeChat(
      disputeId: disputeId ?? this.disputeId,
      adminPubkey: adminPubkey ?? this.adminPubkey,
      userPubkey: userPubkey ?? this.userPubkey,
      disputeToken: disputeToken ?? this.disputeToken,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DisputeChat &&
        other.disputeId == disputeId &&
        other.adminPubkey == adminPubkey &&
        other.userPubkey == userPubkey &&
        other.disputeToken == disputeToken;
  }

  @override
  int get hashCode => Object.hash(
        disputeId,
        adminPubkey,
        userPubkey,
        disputeToken,
      );

  @override
  String toString() => 'DisputeChat('
      'disputeId: $disputeId, '
      'adminPubkey: $adminPubkey, '
      'userPubkey: $userPubkey, '
      'messages: ${messages.length}, '
      'disputeToken: $disputeToken'
      ')';
}
