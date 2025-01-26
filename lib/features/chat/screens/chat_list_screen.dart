import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mostro_mobile/data/models/chat_model.dart';
import 'package:mostro_mobile/features/chat/notifiers/chat_list_state.dart';
import 'package:mostro_mobile/features/chat/providers/chat_list_provider.dart';
import 'package:mostro_mobile/presentation/widgets/bottom_nav_bar.dart';
import 'package:mostro_mobile/presentation/widgets/custom_app_bar.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the state
    final chatListState = ref.watch(chatListNotifierProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1D212C),
      appBar: const CustomAppBar(),
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
                'Chats',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: GoogleFonts.robotoCondensed().fontFamily,
                ),
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

  Widget _buildBody(ChatListState state) {
    switch (state.status) {
      case ChatListStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case ChatListStatus.loaded:
        if (state.chats.isEmpty) {
          return const Center(
              child: Text('No chats available',
                  style: TextStyle(color: Colors.white)));
        }
        return ListView.builder(
          itemCount: state.chats.length,
          itemBuilder: (context, index) {
            return ChatListItem(chat: state.chats[index]);
          },
        );
      case ChatListStatus.error:
        return Center(
          child: Text(
            state.errorMessage ?? 'An error occurred',
            style: const TextStyle(color: Colors.red),
          ),
        );
      case ChatListStatus.empty:
        return const Center(
            child: Text('No chats available',
                style: TextStyle(color: Colors.white)));
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
                style: const TextStyle(color: Colors.white),
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
                          color: Colors.white,
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
