import 'dart:convert';

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

/// A chat envelope costs ~5 EC multiplications to verify + decrypt. With R
/// relays each message used to be unwrapped R times (the handler continued
/// past `alreadyStored`), and every history load re-unwrapped every stored
/// envelope. Already-verified envelopes are now skipped and unwraps are
/// cached per outer id.
class _StubChatRoomsNotifier extends ChatRoomsNotifier {
  _StubChatRoomsNotifier(super.ref);

  @override
  Future<void> loadChats() async {}

  @override
  Future<void> refreshChatList() async {}
}

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

  const orderId = 'a4b7c9e1-0000-4000-8000-redundant-dec';
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
  late ChatCursorStore cursorStore;

  final chatRoomProvider = StateNotifierProvider<ChatRoomNotifier, ChatRoom>(
    (ref) => ChatRoomNotifier(
      ChatRoom(orderId: orderId, messages: []),
      orderId,
      ref,
    ),
  );

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
        await newDatabaseFactoryMemory().openDatabase('redundant_decrypt.db');
    eventStorage = EventStorage(db: db);

    cursorStore = ChatCursorStore(
      _FakeSharedPreferencesAsync(),
      keyPrefix: 'chat_since_',
    );

    container = ProviderContainer(overrides: [
      sessionProvider(orderId).overrideWith((ref) => session),
      eventStorageProvider.overrideWithValue(eventStorage),
      chatCursorStoreProvider.overrideWithValue(cursorStore),
      chatRoomsNotifierProvider
          .overrideWith((ref) => _StubChatRoomsNotifier(ref)),
    ]);
    notifier = container.read(chatRoomProvider.notifier);
  });

  tearDown(() => container.dispose());

  Future<NostrEvent> envelope(String text) {
    final rumor = NostrEventExtensions.createChatRumor(
      senderKeys: peerKey,
      content: text,
    );
    return rumor.chatWrap(chatKeys);
  }

  test('a relay re-delivery of a stored envelope is not unwrapped again',
      () async {
    final event = await envelope('hola');

    await notifier.handleChatEvent(event);
    expect(notifier.debugUnwrapCount, 1);
    expect(container.read(chatRoomProvider).messages, hasLength(1));

    // Same envelope from a second relay.
    await notifier.handleChatEvent(event);

    expect(notifier.debugUnwrapCount, 1,
        reason: 'the stored copy was already verified when first accepted');
    expect(container.read(chatRoomProvider).messages, hasLength(1));
  });

  test('history load reuses the unwrap of a live-handled envelope', () async {
    final event = await envelope('hola');
    await notifier.handleChatEvent(event);
    expect(notifier.debugUnwrapCount, 1);

    await notifier.initialize();

    expect(notifier.debugUnwrapCount, 1,
        reason: 'reloading history must not re-verify and re-decrypt '
            'envelopes already unwrapped in this notifier');
    expect(container.read(chatRoomProvider).messages, hasLength(1));
  });

  test('an envelope stored by the background isolate is still verified',
      () async {
    final event = await envelope('from background');
    // On disk, but this notifier never verified it.
    await eventStorage.putItem(event.id!, event.peerChatRecord(orderId));

    await notifier.handleChatEvent(event);

    expect(notifier.debugUnwrapCount, 1,
        reason: 'an envelope this notifier never verified must be unwrapped, '
            'even though it is already on disk');
    expect(container.read(chatRoomProvider).messages, hasLength(1));
  });

  test('the cursor does not advance from an unverified envelope', () async {
    final real = await envelope('legit');
    await notifier.handleChatEvent(real);
    // The accepted event advances the cursor fire-and-forget; let it land.
    await Future<void>.delayed(Duration.zero);
    final before = await cursorStore.cursorFor(orderId);
    expect(before, isNotNull, reason: 'the verified event advances the cursor');

    // Hostile relay: real envelope id, correct claimed author (both are
    // public), bogus signature and a created_at far in the future.
    final forged = NostrEvent.deserialized('["EVENT","",${jsonEncode({
          'id': real.id,
          'pubkey': chatKeys.sign.public,
          'created_at': DateTime.now()
                  .add(const Duration(days: 3650))
                  .millisecondsSinceEpoch ~/
              1000,
          'kind': 14,
          'tags': <List<String>>[],
          'content': 'undecryptable garbage',
          'sig': '0' * 128,
        })}]');

    await notifier.handleChatEvent(forged);
    await Future<void>.delayed(Duration.zero);

    expect(await cursorStore.cursorFor(orderId), before,
        reason: 'a copy whose signature was never checked must not move the '
            'since cursor: a forged created_at would push it to the local '
            'clock and drop older messages after a reconnect');
  });

  test('concurrent deliveries of the same envelope share one unwrap',
      () async {
    final event = await envelope('hola');

    await Future.wait([
      notifier.handleChatEvent(event),
      notifier.handleChatEvent(event),
    ]);

    expect(notifier.debugUnwrapCount, 1,
        reason: 'the second delivery must join the in-flight unwrap instead '
            'of starting its own');
    expect(container.read(chatRoomProvider).messages, hasLength(1));
  });
}
