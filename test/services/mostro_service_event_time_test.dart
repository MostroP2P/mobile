import 'dart:async';
import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/repositories/event_storage.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_notifier.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager_provider.dart';
import 'package:mostro_mobile/services/mostro_service.dart';
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';
import 'package:mostro_mobile/shared/providers/mostro_database_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../mocks.mocks.dart';

/// A stored message must carry the daemon's event time. Ordering the history
/// by the local receive time alone let an earlier message, replayed or
/// decrypted after a later one, become the order's "latest" message.
const _nodePriv =
    '0000000000000000000000000000000000000000000000000000000000000003';
const _tradePriv =
    '0000000000000000000000000000000000000000000000000000000000000004';
const _orderId = 'order-a';

void main() {
  final nodeKeys = NostrKeyPairs(private: _nodePriv);
  final tradeKeys = NostrKeyPairs(private: _tradePriv);

  late Database db;
  late StreamController<NostrEvent> ordersController;
  late MockSubscriptionManagerSpy subscriptionManager;
  late _FakeSessionNotifier sessions;
  late ProviderContainer container;

  Future<NostrEvent> nodeMessage(Action action, DateTime createdAt) async {
    final tuple = [
      {
        'order': {
          'version': 2,
          'id': _orderId,
          'action': action.value,
          'payload': null,
        },
      },
      null,
    ];
    final encrypted = await NostrUtils.encryptNIP44(
        jsonEncode(tuple), _nodePriv, tradeKeys.public);
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

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    db = await newDatabaseFactoryMemory().openDatabase('event_time.db');
    ordersController = StreamController<NostrEvent>.broadcast();
    subscriptionManager = MockSubscriptionManagerSpy();
    when(subscriptionManager.orders)
        .thenAnswer((_) => ordersController.stream);

    container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(SharedPreferencesAsync()),
      mostroDatabaseProvider.overrideWithValue(db),
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

    sessions.emit([
      Session(
        masterKey: tradeKeys,
        tradeKey: tradeKeys,
        keyIndex: 0,
        fullPrivacy: false,
        startTime: DateTime.now(),
      )..orderId = _orderId,
    ]);
  });

  tearDown(() async {
    await ordersController.close();
    container.dispose();
    await db.close();
  });

  Future<void> deliver(NostrEvent event) async {
    ordersController.add(event);
    final eventStore = EventStorage(db: db);
    await _waitFor(() => eventStore.hasItem(event.id!));
  }

  test('a stored message carries the event created_at in milliseconds',
      () async {
    // Arrange
    final createdAt = DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000);

    // Act
    await deliver(await nodeMessage(Action.waitingSellerToPay, createdAt));

    // Assert
    final history = await container
        .read(mostroStorageProvider)
        .getAllMessagesForOrderId(_orderId);
    expect(history.single.eventCreatedAt, createdAt.millisecondsSinceEpoch);
  });

  test('an earlier event delivered second does not become the latest message',
      () async {
    // Arrange: the relay replays newest-first after a reconnect.
    final base = DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000);
    final newer = await nodeMessage(
        Action.holdInvoicePaymentAccepted, base.add(const Duration(seconds: 30)));
    final older = await nodeMessage(Action.waitingSellerToPay, base);

    // Act
    await deliver(newer);
    await deliver(older);

    // Assert
    final latest = await container
        .read(mostroStorageProvider)
        .getLatestMessageById(_orderId);
    expect(latest?.action, Action.holdInvoicePaymentAccepted);
  });
}

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
