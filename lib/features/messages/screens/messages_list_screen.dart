import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/messages/notifiers/messages_list_state.dart';
import 'package:mostro_mobile/features/messages/providers/messages_list_provider.dart';
import 'package:mostro_mobile/shared/widgets/bottom_nav_bar.dart';
import 'package:mostro_mobile/shared/widgets/mostro_app_bar.dart';
import 'package:mostro_mobile/shared/widgets/mostro_app_drawer.dart';

class MessagesListScreen extends ConsumerWidget {
  const MessagesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the state
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
                'Messages',
                style: AppTheme.theme.textTheme.displayLarge,
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

  Widget _buildBody(MessagesListState state) {
    switch (state.status) {
      case MessagesListStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case MessagesListStatus.loaded:
        if (state.chats.isEmpty) {
          return Center(
              child: Text(
            'No messages available',
            style: AppTheme.theme.textTheme.displaySmall,
          ));
        }
        return ListView.builder(
          itemCount: state.chats.length,
          itemBuilder: (context, index) {
            return ChatListItem(chat: state.chats[index]);
          },
        );
      case MessagesListStatus.error:
        return Center(
          child: Text(
            state.errorMessage ?? 'An error occurred',
            style: const TextStyle(color: Colors.red),
          ),
        );
      case MessagesListStatus.empty:
        return const Center(
            child: Text('No chats available',
                style: TextStyle(color: AppTheme.cream1)));
    }
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
