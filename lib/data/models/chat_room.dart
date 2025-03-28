import 'package:dart_nostr/nostr/model/event/event.dart';

class ChatRoom {
  final String orderId;
  final List<NostrEvent> messages;

  ChatRoom({required this.orderId, required this.messages}) {
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
}
