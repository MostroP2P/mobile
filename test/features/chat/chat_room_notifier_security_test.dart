import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/chat_room.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/models/peer.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/repositories/event_storage.dart';
import 'package:mostro_mobile/features/chat/notifiers/chat_room_notifier.dart';
import 'package:mostro_mobile/features/chat/notifiers/chat_rooms_notifier.dart';
import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/services/chat_cursor_store.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/utils/chat_keys.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Inert chat-list notifier so the handler's refreshChatList side call does
/// not drag the real session/key-manager provider chain into the test.
class _StubChatRoomsNotifier extends ChatRoomsNotifier {
  _StubChatRoomsNotifier(super.ref);

  @override
  Future<void> loadChats() async {}

  @override
  Future<void> refreshChatList() async {}
}

/// Minimal in-memory double for the two methods the cursor store uses.
class _FakeSharedPreferencesAsync implements SharedPreferencesAsync {
  final Map<String, int> ints = {};

  @override
  Future<int?> getInt(String key) async => ints[key];

  @override
  Future<void> setInt(String key, int value) async {
    ints[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const orderId = 'a4b7c9e1-0000-4000-8000-chat-security';
  final ownKey = NostrKeyPairs(
    private:
        '0000000000000000000000000000000000000000000000000000000000000001',
  );
  final peerKey = NostrKeyPairs(
    private:
        '0000000000000000000000000000000000000000000000000000000000000002',
  );

  late Session session;
  late EventStorage eventStorage;
  late ProviderContainer container;
  late ChatRoomNotifier notifier;
  late ChatKeys chatKeys;

  final chatRoomProvider = StateNotifierProvider<ChatRoomNotifier, ChatRoom>(
    (ref) => ChatRoomNotifier(
      ChatRoom(orderId: orderId, messages: []),
      orderId,
      ref,
    ),
  );

  /// A copy of [event] whose signature is well-formed but signed by a key
  /// that is not K_sign. The event id is unchanged: signatures are not part
  /// of the Nostr event id.
  NostrEvent corruptSignature(NostrEvent event) {
    return NostrEvent(
      id: event.id,
      kind: event.kind,
      content: event.content,
      sig: _forgerKey.sign(event.id!),
      pubkey: event.pubkey,
      createdAt: event.createdAt,
      tags: event.tags,
    );
  }

  setUp(() async {
    session = Session(
      masterKey: ownKey,
      tradeKey: ownKey,
      keyIndex: 1,
      fullPrivacy: false,
      startTime: DateTime.now(),
      orderId: orderId,
    )..peer = Peer(publicKey: peerKey.public);
    chatKeys = ChatKeys.fromSharedKey(session.sharedKey!);

    final db =
        await newDatabaseFactoryMemory().openDatabase('chat_security.db');
    eventStorage = EventStorage(db: db);

    container = ProviderContainer(
      overrides: [
        sessionProvider(orderId).overrideWith((ref) => session),
        eventStorageProvider.overrideWithValue(eventStorage),
        chatCursorStoreProvider.overrideWithValue(
          ChatCursorStore(_FakeSharedPreferencesAsync(),
              keyPrefix: 'chat_since_'),
        ),
        chatRoomsNotifierProvider.overrideWith(
          (ref) => _StubChatRoomsNotifier(ref),
        ),
      ],
    );
    notifier = container.read(chatRoomProvider.notifier);
  });

  tearDown(() {
    container.dispose();
  });

  group('envelope authentication before persistence', () {
    test(
        'a signature-corrupted copy delivered first does not suppress the '
        'valid event with the same id', () async {
      final rumor = NostrEventExtensions.createChatRumor(
        senderKeys: peerKey,
        content: 'hello from the peer',
      );
      final valid = await rumor.chatWrap(chatKeys);
      final corrupted = corruptSignature(valid);

      // Malicious relay wins the race with the corrupted copy
      await notifier.handleChatEvent(corrupted);

      expect(await eventStorage.hasItem(valid.id!), isFalse,
          reason: 'an unauthenticated envelope must never be persisted');
      expect(container.read(chatRoomProvider).messages, isEmpty);

      // Honest relay delivers the valid copy afterwards
      await notifier.handleChatEvent(valid);

      expect(await eventStorage.hasItem(valid.id!), isTrue);
      final messages = container.read(chatRoomProvider).messages;
      expect(messages, hasLength(1));
      expect(messages.single.content, equals('hello from the peer'));
      expect(messages.single.id, equals(rumor.id));
    });

    test('duplicate deliveries of a valid event are still deduplicated',
        () async {
      final rumor = NostrEventExtensions.createChatRumor(
        senderKeys: peerKey,
        content: 'once only',
      );
      final valid = await rumor.chatWrap(chatKeys);

      await notifier.handleChatEvent(valid);
      await notifier.handleChatEvent(valid);

      expect(container.read(chatRoomProvider).messages, hasLength(1));
    });

    test(
        'an event the background already persisted still reaches the UI',
        () async {
      final rumor = NostrEventExtensions.createChatRumor(
        senderKeys: peerKey,
        content: 'stored while the app slept',
      );
      final valid = await rumor.chatWrap(chatKeys);

      // The background service persists accepted envelopes but cannot touch
      // the foreground state, so the record is on disk before the notifier
      // ever sees the event
      await eventStorage.putItem(valid.id!, valid.peerChatRecord(orderId));

      await notifier.handleChatEvent(valid);

      final messages = container.read(chatRoomProvider).messages;
      expect(messages, hasLength(1),
          reason: 'a stored-but-unseen event must not be dropped by dedup');
      expect(messages.single.content, equals('stored while the app slept'));
    });

    test('an event from a stranger author is ignored and not persisted',
        () async {
      final stranger = _forgerKey;
      final rumor = NostrEventExtensions.createChatRumor(
        senderKeys: peerKey,
        content: 'wrong author',
      );
      final wrapped = await rumor.chatWrap(chatKeys);
      final wrongAuthor = NostrEvent.fromPartialData(
        kind: 14,
        content: wrapped.content!,
        keyPairs: stranger,
        tags: wrapped.tags,
        createdAt: wrapped.createdAt,
      );

      await notifier.handleChatEvent(wrongAuthor);

      expect(await eventStorage.hasItem(wrongAuthor.id!), isFalse);
      expect(container.read(chatRoomProvider).messages, isEmpty);
    });
  });
}

/// Deterministic third-party key used to forge signatures in tests.
final _forgerKey = NostrKeyPairs(
  private:
      '0000000000000000000000000000000000000000000000000000000000000003',
);
