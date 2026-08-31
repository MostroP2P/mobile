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

    container = ProviderContainer(overrides: [
      sessionProvider(orderId).overrideWith((ref) => session),
      eventStorageProvider.overrideWithValue(eventStorage),
      chatCursorStoreProvider.overrideWithValue(
        ChatCursorStore(_FakeSharedPreferencesAsync(),
              keyPrefix: 'chat_since_'),
      ),
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
}
