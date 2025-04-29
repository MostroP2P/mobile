import 'dart:async';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/chat_room.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/providers/session_manager_provider.dart';

class ChatRoomNotifier extends StateNotifier<ChatRoom> {
  final _logger = Logger();
  final String orderId;
  final Ref ref;
  late StreamSubscription<NostrEvent> subscription;

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
    if(session.sharedKey == null) {
      _logger.e('Shared key is null');
      return;
    }
    final filter = NostrFilter(
      kinds: [1059],
      p: [session.sharedKey!.public],
    );
    final request = NostrRequest(
      filters: [filter],
    );
    subscription =
        ref.read(nostrServiceProvider).subscribeToEvents(request).listen(
      (event) async {
        try {
          final chat = await event.mostroUnWrap(session.sharedKey!);
          // Deduplicate by message ID and always sort by createdAt
          final allMessages = [
            ...state.messages,
            chat,
          ];
          // Use a map to deduplicate by event id
          final deduped = {
            for (var m in allMessages) m.id: m
          }.values.toList();
          deduped.sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
          state = state.copy(messages: deduped);
        } catch (e) {
          _logger.e(e);
        }
      },
    );
  }

  Future<void> sendMessage(String text) async {
    final session = ref.read(sessionProvider(orderId));
    final event = NostrEvent.fromPartialData(
      keyPairs: session!.tradeKey,
      content: text,
      kind: 1,
    );

    final wrappedEvent = await event.mostroWrap(session.sharedKey!);
    ref.read(nostrServiceProvider).publishEvent(wrappedEvent);
  }

  @override
  void dispose() {
    subscription.cancel();
    super.dispose();
  }
}
