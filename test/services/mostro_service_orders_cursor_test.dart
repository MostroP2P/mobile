import 'dart:async';
import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/repositories/event_storage.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_notifier.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager_provider.dart';
import 'package:mostro_mobile/services/chat_cursor_store.dart';
import 'package:mostro_mobile/services/mostro_service.dart';
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../mocks.mocks.dart';

/// The orders `since` cursor is shared by every session of one node, so it
/// must only ever move to a point past which nothing still needs replaying:
/// it feeds the kind-14 filter alone, and it must not step over an event
/// that was deliberately left unmarked for a later retry.
const _nodePriv =
    '0000000000000000000000000000000000000000000000000000000000000003';
const _tradePriv =
    '0000000000000000000000000000000000000000000000000000000000000004';

void main() {
  final nodeKeys = NostrKeyPairs(private: _nodePriv);
  final tradeKeys = NostrKeyPairs(private: _tradePriv);

  late Database db;
  late StreamController<NostrEvent> ordersController;
  late MockSubscriptionManagerSpy subscriptionManager;
  late _FakeSessionNotifier sessions;
  late ProviderContainer container;
  late ChatCursorStore cursorStore;

  /// A node message whose payload is an empty tuple: accepted and marked
  /// processed by the shortest path through `_processEvent`.
  Future<NostrEvent> nodeMessage({DateTime? createdAt}) async {
    final encrypted =
        await NostrUtils.encryptNIP44(jsonEncode([]), _nodePriv, tradeKeys.public);
    return NostrEvent.fromPartialData(
      kind: 14,
      content: encrypted,
      keyPairs: nodeKeys,
      createdAt: createdAt,
      tags: [
        ['p', tradeKeys.public],
      ],
    );
  }

  /// A kind-14 addressed to a trade key no session holds: left unmarked so a
  /// later replay can retry it once the session exists.
  NostrEvent orphanMessage({required DateTime createdAt}) =>
      NostrEvent.fromPartialData(
        kind: 14,
        content: 'undecryptable',
        keyPairs: nodeKeys,
        createdAt: createdAt,
        tags: [
          ['p', 'a' * 64],
        ],
      );

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    db = await newDatabaseFactoryMemory().openDatabase('orders_cursor.db');
    ordersController = StreamController<NostrEvent>.broadcast();
    subscriptionManager = MockSubscriptionManagerSpy();
    when(subscriptionManager.orders)
        .thenAnswer((_) => ordersController.stream);

    container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(SharedPreferencesAsync()),
      eventStorageProvider.overrideWithValue(EventStorage(db: db)),
      subscriptionManagerProvider.overrideWithValue(subscriptionManager),
      settingsProvider
          .overrideWith((ref) => _FixedSettingsNotifier(nodeKeys.public)),
      sessionNotifierProvider.overrideWith((ref) {
        sessions = _FakeSessionNotifier(ref);
        return sessions;
      }),
      mostroServiceProvider.overrideWith((ref) => MostroService(ref)..init()),
    ]);
    container.read(sessionNotifierProvider);
    container.read(mostroServiceProvider);
    cursorStore = container.read(ordersCursorStoreProvider);

    sessions.emit([
      Session(
        masterKey: tradeKeys,
        tradeKey: tradeKeys,
        keyIndex: 0,
        fullPrivacy: false,
        startTime: DateTime.now(),
      )..orderId = 'order-a',
    ]);
  });

  tearDown(() async {
    await ordersController.close();
    container.dispose();
    await db.close();
  });

  MostroService service() => container.read(mostroServiceProvider);

  /// Delivers [event] and waits for the pipeline to actually settle, rather
  /// than for a fixed delay: processing runs an off-isolate NIP-44 decrypt, a
  /// Sembast write and a SharedPreferences write, none of which this test can
  /// await directly. A held event settles once it holds the cursor back; a
  /// processed one settles once its durable marker is written (which is what
  /// _markEventProcessed writes before advancing the cursor).
  Future<void> deliver(NostrEvent event, {bool held = false}) async {
    ordersController.add(event);
    final eventStore = EventStorage(db: db);
    await _waitFor(() async => held
        ? service().debugHeldEventIds.contains(event.id)
        : await eventStore.hasItem(event.id!));
  }

  test('a processed kind-14 event advances the orders cursor', () async {
    final event = await nodeMessage();

    await deliver(event);

    // The advance itself is fire-and-forget after the marker is written.
    await _waitFor(
        () async => await cursorStore.cursorFor(nodeKeys.public) != null);
    final cursor = await cursorStore.cursorFor(nodeKeys.public);
    expect(cursor, isNotNull);
    expect(cursor!.millisecondsSinceEpoch ~/ 1000,
        event.createdAt!.millisecondsSinceEpoch ~/ 1000);
  });

  test('a processed gift wrap does not advance the kind-14 cursor', () async {
    // Gift wrap timestamps are randomized +/- 48 h; letting one move this
    // cursor would push `since` past real kind-14 messages.
    final wrap = await NostrUtils.createNIP59Event(
      jsonEncode([]),
      tradeKeys.public,
      _nodePriv,
    );

    await deliver(wrap);

    expect(await cursorStore.cursorFor(nodeKeys.public), isNull,
        reason: 'only the kind-14 transport owns this cursor');
  });

  test('an older unmarked event holds the cursor back', () async {
    final now = DateTime.now();
    // Arrives for a trade key whose session does not exist yet: not marked,
    // so a later replay must still cover it.
    await deliver(
      orphanMessage(createdAt: now.subtract(const Duration(minutes: 30))),
      held: true,
    );

    // A newer message for another session must not evict it from the window.
    await deliver(await nodeMessage(createdAt: now));

    expect(await cursorStore.cursorFor(nodeKeys.public), isNull,
        reason: 'the cursor is a contiguous watermark, not a high-water mark');
  });
}

/// Polls [condition] until it holds or [timeout] elapses, yielding to the
/// event loop between attempts.
Future<void> _waitFor(
  Future<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await condition() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class _FixedSettingsNotifier extends SettingsNotifier {
  _FixedSettingsNotifier(String mostroPublicKey)
      : super(MockSharedPreferencesAsync()) {
    state = Settings(
      relays: const [],
      fullPrivacyMode: false,
      mostroPublicKey: mostroPublicKey,
    );
  }
}

class _FakeSessionNotifier extends SessionNotifier {
  _FakeSessionNotifier(Ref ref)
      : super(ref, MockSessionStorage(), MockSettings()) {
    state = const [];
  }

  void emit(List<Session> sessions) => state = sessions;
}
