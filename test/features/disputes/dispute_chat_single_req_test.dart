import 'dart:async';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/repositories/event_storage.dart';
import 'package:mostro_mobile/features/disputes/notifiers/dispute_chat_notifier.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager_provider.dart';
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';
import 'package:mostro_mobile/shared/utils/chat_keys.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../mocks.mocks.dart';

/// The dispute chat notifier used to open its OWN kind-14 REQ — a duplicate
/// of the one `SubscriptionManager` already maintains for
/// `SubscriptionType.disputeChat` (whose stream nobody consumed) — and
/// resolved its session by scanning every session and instantiating an
/// `OrderNotifier` (DB sync + subscriptions) per candidate, on EVERY
/// incoming event. It now consumes the manager's stream and resolves the
/// session through the persisted `session.disputeId`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const disputeId = 'dispute-single-req';
  const orderId = 'order-single-req';
  final tradeKey = NostrKeyPairs(
    private:
        '0000000000000000000000000000000000000000000000000000000000000005',
  );
  final adminKey = NostrKeyPairs(
    private:
        '0000000000000000000000000000000000000000000000000000000000000006',
  );

  late Session session;
  late StreamController<NostrEvent> disputeStream;
  late MockSubscriptionManagerSpy manager;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();

    session = Session(
      masterKey: tradeKey,
      tradeKey: tradeKey,
      keyIndex: 1,
      fullPrivacy: false,
      startTime: DateTime.now(),
      orderId: orderId,
    )
      ..disputeId = disputeId
      ..setAdminPeer(adminKey.public);

    disputeStream = StreamController<NostrEvent>.broadcast();
    manager = MockSubscriptionManagerSpy();
    when(manager.disputeChat).thenAnswer((_) => disputeStream.stream);

    final db = await newDatabaseFactoryMemory()
        .openDatabase('dispute_single_req.db');

    container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(SharedPreferencesAsync()),
      eventStorageProvider.overrideWithValue(EventStorage(db: db)),
      subscriptionManagerProvider.overrideWithValue(manager),
      mostroServiceProvider
          .overrideWith((ref) => throw UnimplementedError('unused')),
      sessionNotifierProvider
          .overrideWith((ref) => _FixedSessionNotifier(ref, [session])),
      // The old resolution instantiated an OrderNotifier per session per
      // event; the disputeId lookup must never need one.
      orderNotifierProvider.overrideWith(
        (ref, id) =>
            throw StateError('session resolution must not build notifiers'),
      ),
    ]);
    addTearDown(container.dispose);
    addTearDown(disputeStream.close);
  });

  Future<NostrEvent> adminEnvelope(String text) {
    final chatKeys = ChatKeys.fromSharedKey(session.adminSharedKey!);
    final rumor = NostrEventExtensions.createChatRumor(
      senderKeys: adminKey,
      content: text,
    );
    return rumor.chatWrap(chatKeys);
  }

  test('events from the shared manager stream reach the notifier', () async {
    container.read(disputeChatNotifierProvider(disputeId).notifier);
    await pumpEventQueue(times: 50);

    disputeStream.add(await adminEnvelope('hola admin'));

    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (container
            .read(disputeChatNotifierProvider(disputeId))
            .messages
            .isEmpty &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    final messages =
        container.read(disputeChatNotifierProvider(disputeId)).messages;
    expect(messages, hasLength(1),
        reason: 'the notifier must consume SubscriptionManager.disputeChat '
            'instead of opening its own REQ, and resolve its session via '
            'session.disputeId without touching order notifiers');
    expect(messages.single.content, 'hola admin');
  });
}

/// Session list the notifier can read without touching storage.
class _FixedSessionNotifier extends SessionNotifier {
  _FixedSessionNotifier(Ref ref, List<Session> sessions)
      : super(ref, MockSessionStorage(), MockSettings()) {
    state = sessions;
  }
}
