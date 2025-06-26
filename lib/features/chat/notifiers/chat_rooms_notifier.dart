import 'dart:async';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/chat_room.dart';

import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager_provider.dart';

class ChatRoomsNotifier extends StateNotifier<List<ChatRoom>> {
  final Ref ref;
  final _logger = Logger();

  StreamSubscription<NostrEvent>? _chatSubscription;

  ChatRoomsNotifier(this.ref) : super(const []) {
    loadChats();
    //_setupChatSubscription();
  }
  
  void _setupChatSubscription() {
    final subscriptionManager = ref.read(subscriptionManagerProvider);
    
    // Subscribe to the chat stream from SubscriptionManager
    // The SubscriptionManager will automatically manage subscriptions based on session changes
    _chatSubscription = subscriptionManager.chat.listen(
      _onChatEvent,
      onError: (error, stackTrace) {
        _logger.e('Error in chat subscription', error: error, stackTrace: stackTrace);
      },
      cancelOnError: false,
    );
    
    _logger.i('Chat subscription set up');
  }
  /// Handle incoming chat events
  void _onChatEvent(NostrEvent event) {
    try {
      // Find the chat room this event belongs to
      final orderId = _findOrderIdForEvent(event);
      if (orderId == null) {
        _logger.w('Could not determine orderId for chat event: ${event.id}');
        return;
      }

      // Store the event in the event store so it can be processed by the chat room notifier
      final eventStore = ref.read(eventStorageProvider);
      eventStore.putItem(event.id!, event).then((_) {
        // Trigger a reload of the chat room to process the new event
        final chatRoomNotifier = ref.read(chatRoomsProvider(orderId).notifier);
        if (chatRoomNotifier.mounted) {
          chatRoomNotifier.reload();
        }
      }).catchError((error, stackTrace) {
        _logger.e('Error storing chat event', error: error, stackTrace: stackTrace);
      });
    } catch (e, stackTrace) {
      _logger.e('Error processing chat event', error: e, stackTrace: stackTrace);
    }
  }

  String? _findOrderIdForEvent(NostrEvent event) {
    final sessions = ref.read(sessionNotifierProvider);
    for (final session in sessions) {
      if (session.peer?.publicKey == event.pubkey) {
        return session.orderId;
      }
    }

    return null;
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
    final cutoff = now.subtract(const Duration(hours: 36));

    try {
      final chats = sessions
          .where(
        (s) => s.peer != null && s.startTime.isAfter(cutoff),
      )
          .map((s) {
        final chat = ref.read(chatRoomsProvider(s.orderId!));
        return chat;
      }).toList();
      if (chats.isNotEmpty) {
        state = chats;
      } else {
        _logger.i("No chats found for sessions, keeping previous state.");
      }
    } catch (e) {
      _logger.e(e);
    }
  }

  void _refreshAllSubscriptions() {
    // No need to manually refresh subscriptions
    // SubscriptionManager now handles this automatically based on SessionNotifier changes
    _logger.i('Subscription management is now handled by SubscriptionManager');
    
    // Just reload the chat rooms from the current sessions
    //loadChats();
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    super.dispose();
  }
}
