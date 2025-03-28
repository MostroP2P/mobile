import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/chat_room.dart';
import 'package:mostro_mobile/features/messages/providers/chat_room_providers.dart';
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';
import 'package:mostro_mobile/shared/providers/session_manager_provider.dart';

class ChatRoomsNotifier extends StateNotifier<List<ChatRoom>> {
  final SessionNotifier sessionNotifier;
  final Ref ref;
  final _logger = Logger();

  ChatRoomsNotifier(this.ref, this.sessionNotifier) : super(const []) {
    loadChats();
  }

  Future<void> loadChats() async {
    final sessions = ref.watch(sessionNotifierProvider.notifier).sessions;
    try {
      state = sessions.where((s) => s.peer != null).map((s) {
        final chat = ref.read(chatRoomsProvider(s.orderId!));
        return chat;
      }).toList();
    } catch (e) {
      _logger.e(e);
    }
  }
}
