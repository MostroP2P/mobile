import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/chat_room.dart';
import 'package:mostro_mobile/features/chat/widgets/message_bubble.dart';

class ChatMessagesList extends StatefulWidget {
  final ChatRoom chatRoom;
  final String peerPubkey;
  final ScrollController? scrollController; // Optional external scroll controller

  const ChatMessagesList({
    super.key,
    required this.chatRoom,
    required this.peerPubkey,
    this.scrollController,
  });

  @override
  State<ChatMessagesList> createState() => _ChatMessagesListState();
}

class _ChatMessagesListState extends State<ChatMessagesList> {
  late ScrollController _scrollController;
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    // Use the provided controller or create our own
    _scrollController = widget.scrollController ?? ScrollController();
    
    // Scroll to bottom on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animate: false);
    });
  }

  @override
  void dispose() {
    // Only dispose the controller if we created it
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }



  @override
  void didUpdateWidget(ChatMessagesList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-scroll to bottom when new messages arrive
    if (widget.chatRoom.messages.length != oldWidget.chatRoom.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(animate: true);
      });
    }
    // Also scroll to bottom on first load if messages are available
    else if (_isFirstLoad && widget.chatRoom.messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(animate: false);
        _isFirstLoad = false;
      });
    }
  }

  // Make this method public so it can be called from outside
  void scrollToBottom({bool animate = true}) {
    // Ensure we're not in the middle of a build cycle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && 
          widget.chatRoom.messages.isNotEmpty && 
          _scrollController.position.maxScrollExtent > 0) {
        try {
          if (animate) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          } else {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        } catch (e) {
          // Silently handle any scroll errors
          // This prevents exceptions from breaking the UI
        }
      }
    });
  }
  
  // Keep the private method for internal use
  void _scrollToBottom({required bool animate}) {
    scrollToBottom(animate: animate);
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
        // Add physics for better scrolling performance with many messages
        physics: const AlwaysScrollableScrollPhysics(),
        // Add caching for better performance with many messages
        cacheExtent: 1000,
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