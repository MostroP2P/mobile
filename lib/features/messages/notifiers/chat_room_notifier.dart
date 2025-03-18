import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/chat_room.dart';

class ChatRoomNotifier extends StateNotifier<ChatRoom> {
  ChatRoomNotifier(super.state);

  Future<void> subscribe(Stream<NostrEvent> stream) async {}

  void sendMessage(String text) {}
}
