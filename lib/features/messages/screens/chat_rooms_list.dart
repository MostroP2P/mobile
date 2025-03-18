import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/chat_room.dart';
import 'package:mostro_mobile/features/messages/providers/chat_room_providers.dart';
import 'package:mostro_mobile/shared/widgets/bottom_nav_bar.dart';
import 'package:mostro_mobile/shared/widgets/mostro_app_bar.dart';
import 'package:mostro_mobile/shared/widgets/mostro_app_drawer.dart';

class ChatRoomsScreen extends ConsumerWidget {
  const ChatRoomsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatListState = ref.watch(messagesListNotifierProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1D212C),
      appBar: const MostroAppBar(),
      drawer: const MostroAppDrawer(),
      body: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF303544),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'MESSAGES',
                style: TextStyle(color: AppTheme.mostroGreen),
              ),
            ),
            Expanded(
              child: _buildBody(chatListState),
            ),
            const BottomNavBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<ChatRoom> state) {
    if (state.isEmpty) {
      return Center(
          child: Text(
        'No messages available',
        style: AppTheme.theme.textTheme.displaySmall,
      ));
    }
    return ListView.builder(
      itemCount: state.length,
      itemBuilder: (context, index) {
        return ChatListItem(chat: state[index].messages.first);
      },
    );
  }
}

class ChatListItem extends StatelessWidget {
  final NostrEvent chat;

  const ChatListItem({super.key, required this.chat});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D212C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.grey,
              child: Text(
                chat.pubkey.isNotEmpty ? chat.pubkey[0] : '?',
                style: const TextStyle(color: AppTheme.cream1),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        chat.pubkey,
                        style: const TextStyle(
                          color: AppTheme.cream1,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        chat.createdAt!.toIso8601String(),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    chat.content!,
                    style: const TextStyle(color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (chat.isVerified())
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF8CC541),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
