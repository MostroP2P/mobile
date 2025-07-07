import 'package:dart_nostr/nostr/model/event/event.dart';

class ChatRoom {
  final String orderId;
  final List<NostrEvent> messages;

  ChatRoom({required this.orderId, required this.messages}) {
    if (orderId.isEmpty) {
      throw ArgumentError('Order ID cannot be empty');
    }
    messages.sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
  }

  ChatRoom copy({
    List<NostrEvent>? messages,
  }) {
    return ChatRoom(
      orderId: orderId,
      messages: messages ?? this.messages,
    );
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatRoom &&
        other.orderId == orderId &&
        _listEquals(other.messages, messages);
  }
  
  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
  
  @override
  int get hashCode => Object.hash(orderId, messages.length);
  
  @override
  String toString() => 'ChatRoom(orderId: $orderId, messages: ${messages.length} messages)';
}
