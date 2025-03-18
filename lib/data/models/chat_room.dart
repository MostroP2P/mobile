import 'package:dart_nostr/nostr/model/event/event.dart';

class ChatRoom {
  final List<NostrEvent> messages = [];

  void sortMessages() {
    messages.sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
  }
}
