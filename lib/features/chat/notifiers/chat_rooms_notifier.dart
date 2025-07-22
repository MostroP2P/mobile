import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/chat_room.dart';

import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';

class ChatRoomsNotifier extends StateNotifier<List<ChatRoom>> {
  final Ref ref;
  final _logger = Logger();

  ChatRoomsNotifier(this.ref) : super(const []) {
    loadChats();
  }
  

  void reloadAllChats() {
    for (final chat in state) {
      try {
        final notifier = ref.read(chatRoomsProvider(chat.orderId).notifier);
        if (notifier.mounted) {
          notifier.reload();
        }
      } catch (e) {
        _logger.e('Failed to reload chat for orderId ${chat.orderId}: $e');
      }
    }

    _refreshAllSubscriptions();
  }

  Future<void> loadChats() async {
    final sessions = ref.read(sessionNotifierProvider);
    if (sessions.isEmpty) {
      _logger.i("No sessions yet, skipping chat load.");
      return;
    }
    final now = DateTime.now();

    try {
      final chats = sessions
          .where(
        (s) =>
            s.orderId != null &&
            (s.peer != null ||
                s.startTime.isAfter(now.subtract(const Duration(hours: 1)))),
      )
          .map((s) {
        final chat = ref.read(chatRoomsProvider(s.orderId!));
        return chat;
      }).toList();

      state = chats;
      _logger.i("Loaded ${chats.length} chats");
    } catch (e) {
      _logger.e("Error loading chats: $e");
    }
  }

  /// Refresh the chat list to reflect new messages and updated order
  Future<void> refreshChatList() async {
    final sessions = ref.read(sessionNotifierProvider.notifier).sessions;
    if (sessions.isEmpty) {
      return;
    }
    final now = DateTime.now();

    try {
      // Add a small delay to ensure state has been updated
      await Future.delayed(const Duration(milliseconds: 100));
      
      final chats = sessions
          .where(
        (s) =>
            s.orderId != null &&
            (s.peer != null ||
                s.startTime.isAfter(now.subtract(const Duration(hours: 1)))),
      )
          .map((s) {
        // Force a fresh read of the chat state
        final chat = ref.read(chatRoomsProvider(s.orderId!));
        return chat;
      }).toList();

      // Force update the state to trigger UI refresh
      state = [...chats];
      _logger.d("Refreshed ${chats.length} chats with updated messages");
    } catch (e) {
      _logger.e("Error refreshing chats: $e");
    }
  }

  void _refreshAllSubscriptions() {
    // No need to manually refresh subscriptions
    // SubscriptionManager now handles this automatically based on SessionNotifier changes
    _logger.i('Subscription management is now handled by SubscriptionManager');
    
    // Just reload the chat rooms from the current sessions
    //loadChats();
  }

}
