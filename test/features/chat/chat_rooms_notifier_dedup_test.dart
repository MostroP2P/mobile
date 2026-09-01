import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/chat_room.dart';
import 'package:mostro_mobile/data/models/peer.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/chat/notifiers/chat_room_notifier.dart';
import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../mocks.mocks.dart';

/// `KeyManager.getNextKeyIndex` used to hand out an already-reserved trade
/// key index, so two sessions could share a trade key. With a common
/// counterparty they also share the ECDH shared key the chat envelope keys
/// are derived from, and both chat rooms then accept the very same messages.
/// Sessions created before that fix are still on disk, so the list collapses
/// them into a single row.
void main() {
  const olderOrderId = 'order-older';
  const newerOrderId = 'order-newer';
  // A real curve point: the shared key is a genuine ECDH computation.
  final peerPubkey = NostrKeyPairs(
    private:
        '5566778899aabbccddeeff00112233445566778899aabbccddeeff0011223344',
  ).public;
  // Both sessions carry this trade key, which is exactly the collision.
  const sharedTradeKey =
      'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890';

  late ProviderContainer container;
  late Map<String, List<NostrEvent>> messagesByOrderId;

  NostrEvent message(String id) => NostrEvent(
        id: id,
        kind: 14,
        content: 'hola',
        sig: '',
        pubkey: 'peer-pubkey',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
        tags: const [],
      );

  Session session({
    required String orderId,
    required DateTime startTime,
    String tradeKeyPrivate = sharedTradeKey,
  }) {
    final s = Session(
      masterKey: NostrKeyPairs(
          private:
              '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef'),
      tradeKey: NostrKeyPairs(private: tradeKeyPrivate),
      keyIndex: 0,
      fullPrivacy: false,
      startTime: startTime,
      peer: Peer(publicKey: peerPubkey),
    );
    s.orderId = orderId;
    return s;
  }

  void arrange(List<Session> sessions) {
    container = ProviderContainer(overrides: [
      sessionNotifierProvider.overrideWith((ref) {
        final notifier = _FakeSessionNotifier(ref);
        notifier.emit(sessions);
        return notifier;
      }),
      chatRoomsProvider.overrideWith((ref, id) => ChatRoomNotifier(
            ChatRoom(orderId: id, messages: messagesByOrderId[id] ?? <NostrEvent>[]),
            id,
            ref,
          )),
    ]);
    addTearDown(container.dispose);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    messagesByOrderId = {};
  });

  test('two sessions sharing a conversation key render a single row', () {
    // Arrange: both rooms hold the conversation (as they do while the app is
    // running and both notifiers accept the same live envelopes).
    messagesByOrderId = {
      olderOrderId: [message('m1')],
      newerOrderId: [message('m1')],
    };
    arrange([
      session(
        orderId: olderOrderId,
        startTime: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      session(orderId: newerOrderId, startTime: DateTime.now()),
    ]);

    // Act
    final chats = container.read(chatRoomsNotifierProvider);

    // Assert: the newest session wins, and the conversation is shown once.
    expect(chats.map((c) => c.orderId), [newerOrderId]);
  });

  test(
      'the conversation survives when only the older room holds the history',
      () {
    // Arrange: after a restart only one room reloads the history — envelopes
    // are stored globally once, under whichever orderId first handled them
    // (ChatRoomNotifier._onChatEvent), and _loadHistoricalMessages filters on
    // that orderId. Here the newer session's room comes up empty.
    messagesByOrderId = {
      olderOrderId: [message('m1')],
      newerOrderId: <NostrEvent>[],
    };
    arrange([
      session(
        orderId: olderOrderId,
        startTime: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      session(orderId: newerOrderId, startTime: DateTime.now()),
    ]);

    // Act
    final chats = container.read(chatRoomsNotifierProvider);

    // Assert: claiming the conversation for the empty newer room would drop
    // the older one too and make the chat vanish entirely.
    expect(chats.map((c) => c.orderId), [olderOrderId]);
  });

  test('distinct conversations are both kept', () {
    // Arrange: different trade keys, so different ECDH shared keys.
    messagesByOrderId = {
      olderOrderId: [message('m1')],
      newerOrderId: [message('m2')],
    };
    arrange([
      session(
        orderId: olderOrderId,
        startTime: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      session(
        orderId: newerOrderId,
        startTime: DateTime.now(),
        tradeKeyPrivate:
            '0fedcba9876543210fedcba9876543210fedcba9876543210fedcba987654321',
      ),
    ]);

    // Act
    final chats = container.read(chatRoomsNotifierProvider);

    // Assert
    expect(chats.map((c) => c.orderId), [newerOrderId, olderOrderId]);
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
