import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/chat_room.dart';

class ChatRoomsNotifier extends StateNotifier<List<ChatRoom>> {
  ChatRoomsNotifier() : super(const []) {
    loadChats();
  }

  Future<void> loadChats() async {
    try {

    } catch (e) {
    }
  }
}
