import 'dart:async';

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
import 'package:mostro_mobile/services/mostro_service.dart';
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:sembast/sembast_memory.dart';

import '../mocks.mocks.dart';

/// A failed first processing attempt must not poison the event forever.
/// The old flow reserved the event id in the event store BEFORE matching the
/// session and decrypting, so a mid-way failure (session not loaded yet,
/// decrypt error, process death) left the id durably marked: the background
/// service then suppressed its push for it and every later replay skipped it
/// — the daemon's message was lost and the order sat at a stale status
/// across restarts. The marker must be written only after processing
/// completes.
void main() {
  const tradeKeyPrivate =
      'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890';

  late Database db;
  late EventStorage eventStorage;
  late StreamController<NostrEvent> ordersController;
  late MockSubscriptionManagerSpy subscriptionManager;
  late _FakeSessionNotifier sessions;
  late ProviderContainer container;
  late MostroService service;

  NostrEvent eventFor(String id, String recipientPubkey) => NostrEvent(
        id: id,
        kind: 1059,
        content: 'not-a-real-gift-wrap',
        sig: 'sig',
        pubkey: 'ephemeral-pubkey',
        createdAt: DateTime.now(),
        tags: [
          ['p', recipientPubkey],
        ],
      );

  setUp(() async {
    db = await newDatabaseFactoryMemory().openDatabase('event_retry.db');
    eventStorage = EventStorage(db: db);
    ordersController = StreamController<NostrEvent>.broadcast();
    subscriptionManager = MockSubscriptionManagerSpy();
    when(subscriptionManager.orders)
        .thenAnswer((_) => ordersController.stream);

    container = ProviderContainer(overrides: [
      eventStorageProvider.overrideWithValue(eventStorage),
      subscriptionManagerProvider.overrideWithValue(subscriptionManager),
      settingsProvider.overrideWith((ref) => _FixedSettingsNotifier()),
      sessionNotifierProvider.overrideWith((ref) {
        sessions = _FakeSessionNotifier(ref);
        return sessions;
      }),
      mostroServiceProvider.overrideWith((ref) {
        final s = MostroService(ref);
        s.init();
        return s;
      }),
    ]);
    container.read(sessionNotifierProvider);
    service = container.read(mostroServiceProvider);
  });

  tearDown(() async {
    ordersController.close();
    container.dispose();
    await db.close();
  });

  Future<void> deliver(NostrEvent event) async {
    ordersController.add(event);
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  test('an event with no matching session is not marked processed', () async {
    final event = eventFor('event-no-session', 'unknown-recipient');

    await deliver(event);

    expect(await eventStorage.hasItem('event-no-session'), isFalse,
        reason: 'a replay must be able to retry once the session exists');
  });

  test('an event that fails to decrypt is not marked processed', () async {
    final tradeKey = NostrKeyPairs(private: tradeKeyPrivate);
    sessions.emit([
      Session(
        masterKey: tradeKey,
        tradeKey: tradeKey,
        keyIndex: 0,
        fullPrivacy: false,
        startTime: DateTime.now(),
      )..orderId = 'order-a',
    ]);
    final event = eventFor('event-bad-payload', tradeKey.public);

    await deliver(event);

    expect(await eventStorage.hasItem('event-bad-payload'), isFalse,
        reason: 'a transient decrypt failure must stay retryable on replay');
    expect(service, isNotNull);
  });
}

class _FixedSettingsNotifier extends SettingsNotifier {
  _FixedSettingsNotifier() : super(MockSharedPreferencesAsync()) {
    state = Settings(
      relays: const [],
      fullPrivacyMode: false,
      mostroPublicKey: 'mostro-pubkey',
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
