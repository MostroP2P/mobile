import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/chat_room.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/chat/notifiers/chat_room_notifier.dart';
import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/services/chat_read_status_service.dart';
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../mocks.mocks.dart';

/// The unread dot in every chat-list row was a `FutureBuilder` whose future
/// (a SharedPreferences read) was recreated on every rebuild of every row,
/// flickering through `snapshot.data ?? false` each time. It is now a
/// FutureProvider family that recomputes only when the room or the read
/// cursor changes.
void main() {
  const orderId = 'order-a';
  const tradeKeyPrivate =
      'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890';

  late ProviderContainer container;
  late List<NostrEvent> messages;

  NostrEvent message(String id, String pubkey, int createdAt) => NostrEvent(
        id: id,
        kind: 14,
        content: 'hola',
        sig: '',
        pubkey: pubkey,
        createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
        tags: const [],
      );

  Session session() {
    final s = Session(
      masterKey: NostrKeyPairs(
          private:
              '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef'),
      tradeKey: NostrKeyPairs(private: tradeKeyPrivate),
      keyIndex: 0,
      fullPrivacy: false,
      startTime: DateTime.now(),
    );
    s.orderId = orderId;
    return s;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    messages = [];
    container = ProviderContainer(overrides: [
      sessionNotifierProvider.overrideWith((ref) {
        final notifier = _FakeSessionNotifier(ref);
        notifier.emit([session()]);
        return notifier;
      }),
      chatRoomsProvider.overrideWith((ref, id) => ChatRoomNotifier(
            ChatRoom(orderId: id, messages: messages),
            id,
            ref,
          )),
    ]);
  });

  tearDown(() => container.dispose());

  String userPubkey() =>
      container.read(sessionProvider(orderId))!.tradeKey.public;

  test('a peer message with no read cursor is unread', () async {
    messages = [message('m1', 'peer-pubkey', 1000)];

    final unread =
        await container.read(chatHasUnreadProvider(orderId).future);

    expect(unread, isTrue);
  });

  test('own messages never count as unread', () async {
    container.read(sessionNotifierProvider);
    messages = [message('m1', userPubkey(), 1000)];

    final unread =
        await container.read(chatHasUnreadProvider(orderId).future);

    expect(unread, isFalse);
  });

  test('messages older than the read cursor are read', () async {
    await ChatReadStatusService.markChatAsRead(orderId);
    messages = [message('m1', 'peer-pubkey', 1000)];

    final unread =
        await container.read(chatHasUnreadProvider(orderId).future);

    expect(unread, isFalse);
  });

  test('without a session there is nothing unread', () async {
    final unread =
        await container.read(chatHasUnreadProvider('unknown-order').future);

    expect(unread, isFalse);
  });
}

/// Session list the provider can read without touching storage.
class _FakeSessionNotifier extends SessionNotifier {
  _FakeSessionNotifier(Ref ref)
      : super(ref, MockSessionStorage(), MockSettings()) {
    state = const [];
  }

  void emit(List<Session> sessions) => state = sessions;
}
