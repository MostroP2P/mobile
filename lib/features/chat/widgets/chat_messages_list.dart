import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/chat_room.dart';
import 'package:mostro_mobile/features/chat/widgets/message_bubble.dart';

class ChatMessagesList extends StatefulWidget {
  final ChatRoom chatRoom;
  final String peerPubkey;

  const ChatMessagesList({
    super.key,
    required this.chatRoom,
    required this.peerPubkey,
  });

  @override
  State<ChatMessagesList> createState() => _ChatMessagesListState();
}

class _ChatMessagesListState extends State<ChatMessagesList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ChatMessagesList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-scroll to bottom when new messages arrive
    if (widget.chatRoom.messages.length != oldWidget.chatRoom.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sort messages chronologically (oldest first) for proper chat display
    final sortedMessages = List<NostrEvent>.from(widget.chatRoom.messages);
    sortedMessages.sort((a, b) {
      final aTime = a.createdAt is int ? a.createdAt as int : 0;
      final bTime = b.createdAt is int ? b.createdAt as int : 0;
      return aTime.compareTo(bTime); // Oldest first
    });

    return Container(
      padding: const EdgeInsets.all(12),
      color: AppTheme.backgroundDark,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: sortedMessages.length,
        itemBuilder: (context, index) {
          final message = sortedMessages[index];
          return MessageBubble(
            message: message,
            peerPubkey: widget.peerPubkey,
          );
        },
      ),
    );
  }
}