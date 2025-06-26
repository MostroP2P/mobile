import 'dart:async';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/chat_room.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';

class ChatRoomNotifier extends StateNotifier<ChatRoom> {
  /// Reload the chat room by re-subscribing to events.
  void reload() {
    // Cancel the current subscription if it exists
    _subscription?.cancel();
    subscribe();
  }

  final _logger = Logger();
  final String orderId;
  final Ref ref;
  StreamSubscription<NostrEvent>? _subscription;

  ChatRoomNotifier(
    super.state,
    this.orderId,
    this.ref,
  );

  void subscribe() {
    final session = ref.read(sessionProvider(orderId));
    if (session == null) {
      _logger.e('Session is null');
      return;
    }
    if (session.sharedKey == null) {
      _logger.e('Shared key is null');
      return;
    }

    // Use SubscriptionManager to create a subscription for this specific chat room
    final subscriptionManager = ref.read(subscriptionManagerProvider);
    _subscription = subscriptionManager.chat.listen(_onChatEvent);
  }

  void _onChatEvent(NostrEvent event) async {
    try {
      final session = ref.read(sessionProvider(orderId));
      if (session == null || session.sharedKey == null) {
        _logger.e('Session or shared key is null when processing chat event');
        return;
      }

      if (session.sharedKey?.public != event.recipient) {
        return;
      }

      final eventStore = ref.read(eventStorageProvider);

      await eventStore.putItem(
        event.id!,
        event,
      );

      final chat = await event.mostroUnWrap(session.sharedKey!);
      // Deduplicate by message ID and always sort by createdAt
      final allMessages = [
        ...state.messages,
        chat,
      ];
      // Use a map to deduplicate by event id
      final deduped = {for (var m in allMessages) m.id: m}.values.toList();
      deduped.sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
      state = state.copy(messages: deduped);
    } catch (e, stackTrace) {
      _logger.e('Error processing chat event',
          error: e, stackTrace: stackTrace);
    }
  }

  Future<void> sendMessage(String text) async {
    final session = ref.read(sessionProvider(orderId));
    if (session == null) {
      _logger.e('Session is null');
      return;
    }
    if (session.sharedKey == null) {
      _logger.e('Shared key is null');
      return;
    }
    final event = NostrEvent.fromPartialData(
      keyPairs: session.tradeKey,
      content: text,
      kind: 1,
    );

    final wrappedEvent = await event.mostroWrap(session.sharedKey!);
    ref.read(nostrServiceProvider).publishEvent(wrappedEvent);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _logger.i('Disposed chat room notifier for orderId: $orderId');
    super.dispose();
  }
}
