import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as actions;
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/repositories/event_storage.dart';
import 'package:mostro_mobile/features/disputes/notifiers/dispute_chat_notifier.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';
import 'package:mostro_mobile/features/order/notifiers/order_notifier.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/services/mostro_service.dart';
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';
import 'package:mostro_mobile/shared/providers/mostro_database_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';
import 'package:mostro_mobile/shared/utils/chat_keys.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../mocks.mocks.dart';

/// Nostr that is up but delivers nothing: the dispute chat notifier can open
/// its live subscription without a network.
class _SilentNostrService extends NostrService {
  @override
  bool get isInitialized => true;

  @override
  Stream<NostrEvent> subscribeToEvents(NostrRequest request) =>
      const Stream.empty();
}

/// Mostro service that skips `init()`; read by [OrderNotifier]'s constructor.
class _IdleMostroService extends MostroService {
  _IdleMostroService(super.ref);
}

/// [OrderNotifier] pinned to a fixed state carrying the dispute.
class _FixedOrderNotifier extends OrderNotifier {
  _FixedOrderNotifier(super.orderId, super.ref, OrderState fixedState) {
    state = fixedState;
  }

  @override
  Future<void> sync() async {}

  @override
  void subscribe() {}
}

/// Session notifier pinned to a fixed session list; never touches storage.
class _FixedSessionNotifier extends SessionNotifier {
  _FixedSessionNotifier(Ref ref, List<Session> sessions)
      : super(
          ref,
          MockSessionStorage(),
          Settings(
            relays: [],
            fullPrivacyMode: false,
            mostroPublicKey: 'test',
          ),
        ) {
    state = sessions;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const orderId = 'order-1';
  const disputeId = 'dispute-1';

  final tradeKey = NostrKeyPairs(
    private:
        '0000000000000000000000000000000000000000000000000000000000000001',
  );
  final adminKey = NostrKeyPairs(
    private:
        '0000000000000000000000000000000000000000000000000000000000000003',
  );

  late Session session;
  late EventStorage eventStorage;
  late Database db;
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
    )..setAdminPeer(adminKey.public);

    db = await newDatabaseFactoryMemory().openDatabase('dispute_reload.db');
    eventStorage = EventStorage(db: db);

    final orderState = OrderState(
      status: Status.dispute,
      action: actions.Action.disputeInitiatedByYou,
      order: null,
      dispute: Dispute(disputeId: disputeId, orderId: orderId),
    );

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(SharedPreferencesAsync()),
        mostroDatabaseProvider.overrideWithValue(db),
        nostrServiceProvider.overrideWithValue(_SilentNostrService()),
        mostroServiceProvider.overrideWith((ref) => _IdleMostroService(ref)),
        eventStorageProvider.overrideWithValue(eventStorage),
        sessionNotifierProvider
            .overrideWith((ref) => _FixedSessionNotifier(ref, [session])),
        orderNotifierProvider.overrideWith(
          (ref, id) => _FixedOrderNotifier(id, ref, orderState),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// Simulate the background service persisting an accepted admin envelope
  /// to disk (its notification path) while the foreground app sleeps.
  Future<NostrEvent> persistAdminMessageFromBackground(String text) async {
    final chatKeys = ChatKeys.fromSharedKey(session.adminSharedKey!);
    final rumor = NostrEventExtensions.createChatRumor(
      senderKeys: adminKey,
      content: text,
    );
    final wrapped = await rumor.chatWrap(chatKeys);
    await eventStorage.putItem(
      wrapped.id!,
      wrapped.disputeChatRecord(disputeId),
    );
    return rumor;
  }

  test(
      'invalidating the dispute chat family reloads admin messages the '
      'background service persisted while the notifier was alive', () async {
    // Arrange: notifier initialized before the messages arrive
    container.read(disputeChatNotifierProvider(disputeId).notifier);
    await pumpEventQueue();
    expect(
      container.read(disputeChatNotifierProvider(disputeId)).messages,
      isEmpty,
    );

    // Background service stores three admin messages on disk; the alive
    // notifier has no way to see them (this is the reported bug scenario)
    final rumor1 = await persistAdminMessageFromBackground('admin message 1');
    final rumor2 = await persistAdminMessageFromBackground('admin message 2');
    final rumor3 = await persistAdminMessageFromBackground('admin message 3');
    await pumpEventQueue();
    expect(
      container.read(disputeChatNotifierProvider(disputeId)).messages,
      isEmpty,
      reason: 'an already-initialized notifier does not re-read storage',
    );

    // Act: what LifecycleManager now does on foreground resume
    container.invalidate(disputeChatNotifierProvider);
    container.read(disputeChatNotifierProvider(disputeId).notifier);
    await pumpEventQueue(times: 100);

    // Assert: the messages persisted by the background service are visible
    final messages =
        container.read(disputeChatNotifierProvider(disputeId)).messages;
    expect(messages, hasLength(3));
    expect(
      messages.map((m) => m.id),
      containsAll([rumor1.id, rumor2.id, rumor3.id]),
    );
    expect(
      messages.map((m) => m.content),
      containsAll(['admin message 1', 'admin message 2', 'admin message 3']),
    );
  });
}
