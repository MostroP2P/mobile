import 'dart:async';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/chat_room.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/shared/providers/background_service_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
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

  Future<void> init() async {
  final eventStore = ref.read(eventStorageProvider);
    eventStore.watch().listen((data) {
      data.forEach(_handleIncomingEvent);
    });
  }

  void _handleIncomingEvent(NostrEvent event) async {
    final session = ref.read(sessionProvider(event.subscriptionId!));
    if (session == null) return;
    try {
      final chat = await event.mostroUnWrap(session.sharedKey!);
      if (!state.messages.contains(chat)) {
        state = state.copy(
          messages: [
            ...state.messages,
            chat,
          ],
        );
      }
    } catch (e) {
      _logger.e(e);
    }
  }

  void subscribe() {
    final backgroundService = ref.read(backgroundServiceProvider);
    final session = ref.read(sessionProvider(orderId));
    backgroundService.subscribe({
      'kinds' : [1059],
      '#p': [session?.sharedKey!.public],
    });
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
