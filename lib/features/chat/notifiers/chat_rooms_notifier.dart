import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/chat_room.dart';
import 'package:mostro_mobile/data/models/session.dart';

import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';

class ChatRoomsNotifier extends StateNotifier<List<ChatRoom>> {
  final Ref ref;

  ChatRoomsNotifier(this.ref) : super(const []) {
    loadChats();
  }
  

  Future<void> reloadAllChats() async {
    // Iterate over sessions (source of truth) instead of state, which may be
    // empty if loadChats() filtered out chats before async init completed.
    final sessions = ref.read(sessionNotifierProvider);
    final futures = <Future<void>>[];
    for (final session in sessions) {
      if (session.orderId == null || session.peer == null) continue;
      try {
        final notifier = ref.read(chatRoomsProvider(session.orderId!).notifier);
        if (notifier.mounted) {
          futures.add(
            notifier.reload().catchError((e) {
              logger.e('Failed to reload chat for orderId ${session.orderId}: $e');
            }),
          );
        }
      } catch (e) {
        logger.e('Failed to setup reload for orderId ${session.orderId}: $e');
      }
    }

    await Future.wait(futures);
    await refreshChatList();

    _refreshAllSubscriptions();
  }

  Future<void> loadChats() async {
    final sessions = ref.read(sessionNotifierProvider);
    if (sessions.isEmpty) {
      state = [];
      logger.i("No sessions, clearing chat list.");
      return;
    }
    final now = DateTime.now();

    try {
      final chats = _chatsForSessions(sessions, now);

      state = chats;
      logger.i("Loaded ${chats.length} chats with messages");
    } catch (e) {
      logger.e("Error loading chats: $e");
    }
  }

  /// Refresh the chat list to reflect new messages and updated order
  Future<void> refreshChatList() async {
    final sessions = ref.read(sessionNotifierProvider.notifier).sessions;
    if (sessions.isEmpty) {
      state = [];
      return;
    }
    final now = DateTime.now();

    try {
      final chats = _chatsForSessions(sessions, now);

      // Skip the emission when nothing visible changed: this runs after
      // every incoming chat event and a fresh list rebuilds the whole
      // chat-rooms screen.
      final unchanged = state.length == chats.length &&
          () {
            for (var i = 0; i < chats.length; i++) {
              if (state[i].orderId != chats[i].orderId ||
                  state[i].messages.length != chats[i].messages.length ||
                  (state[i].messages.isNotEmpty &&
                      state[i].messages.last.id != chats[i].messages.last.id)) {
                return false;
              }
            }
            return true;
          }();
      if (!unchanged) {
        state = [...chats];
      }
      logger.d("Refreshed ${chats.length} chats with messages");
    } catch (e) {
      logger.e("Error refreshing chats: $e");
    }
  }

  /// Builds the visible chat rooms for [sessions], at most one row per
  /// conversation.
  ///
  /// Two rows can otherwise describe a single conversation:
  ///
  /// - two sessions sharing an orderId resolve to the very same
  ///   [chatRoomsProvider], rendering the identical room twice;
  /// - two sessions sharing a trade key *and* a peer derive the identical
  ///   ECDH shared key, so both accept the very same chat envelopes and each
  ///   stores them under its own orderId. `KeyManager.getNextKeyIndex` used
  ///   to hand out an already-reserved index, which produced exactly this.
  ///
  /// The key collision is fixed at the source, but sessions created before
  /// the fix are still on disk, so collapse them here too and keep the newest.
  List<ChatRoom> _chatsForSessions(List<Session> sessions, DateTime now) {
    final cutoff = now.subtract(const Duration(hours: 1));
    final ordered = [...sessions]
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    final seenOrderIds = <String>{};
    final seenConversations = <String>{};
    final chats = <ChatRoom>[];
    for (final session in ordered) {
      final orderId = session.orderId;
      if (orderId == null) continue;
      if (session.peer == null && !session.startTime.isAfter(cutoff)) continue;
      if (!seenOrderIds.add(orderId)) continue;
      // Resolve the room before claiming anything. Envelopes are stored once
      // globally, under whichever orderId handled them first, and history is
      // reloaded by that orderId — so after a restart only one of two
      // colliding rooms holds the conversation. Claiming for an empty room
      // would drop the one that has the messages and hide the chat entirely.
      final chat = ref.read(chatRoomsProvider(orderId));
      if (chat.messages.isEmpty) continue;
      // Identifies the conversation itself: the chat envelope keys are derived
      // from this shared secret, so an equal value means literally the same
      // messages on both rows.
      final conversationId = session.sharedKey?.public;
      if (conversationId != null && !seenConversations.add(conversationId)) {
        logger.w(
          'Collapsing chat for order $orderId: it shares a conversation key '
          'with another session (colliding trade keys).',
        );
        continue;
      }
      chats.add(chat);
    }
    return chats;
  }

  void _refreshAllSubscriptions() {
    // No need to manually refresh subscriptions
    // SubscriptionManager now handles this automatically based on SessionNotifier changes
    logger.i('Subscription management is now handled by SubscriptionManager');
    
    // Just reload the chat rooms from the current sessions
    //loadChats();
  }

}
