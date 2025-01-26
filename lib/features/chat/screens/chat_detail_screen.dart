import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/features/chat/notifiers/chat_detail_state.dart';
import 'package:mostro_mobile/features/chat/providers/chat_list_provider.dart';
import 'package:mostro_mobile/presentation/widgets/bottom_nav_bar.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  final String chatId;

  const ChatDetailScreen({super.key, required this.chatId});

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final TextEditingController _textController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final chatDetailState = ref.watch(chatDetailNotifierProvider(widget.chatId));

    return Scaffold(
      backgroundColor: const Color(0xFF1D212C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('JACK FOOTSEY'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: _buildBody(chatDetailState),
      bottomNavigationBar: const BottomNavBar(),
    );
  }

  Widget _buildBody(ChatDetailState state) {
    switch (state.status) {
      case ChatDetailStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case ChatDetailStatus.loaded:
        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: state.messages.length,
                itemBuilder: (context, index) {
                  final message = state.messages[index];
                  return _buildMessageBubble(message);
                },
              ),
            ),
            _buildMessageInput(),
          ],
        );
      case ChatDetailStatus.error:
        return Center(child: Text(state.error ?? 'An error occurred'));
    }
  }

  Widget _buildMessageBubble(NostrEvent message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      alignment: message.pubkey == 'Mostro'
          ? Alignment.centerLeft
          : Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: message.pubkey == 'Mostro'
              ? const Color(0xFF303544)
              : const Color(0xFF8CC541),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message.content!,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: const Color(0xFF303544),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: const Color(0xFF1D212C),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Color(0xFF8CC541)),
            onPressed: () {
              final text = _textController.text.trim();
              if (text.isNotEmpty) {
                ref
                    .read(chatDetailNotifierProvider(widget.chatId).notifier)
                    .sendMessage(text);
                _textController.clear();
              }
            },
          ),
        ],
      ),
    );
  }
}
