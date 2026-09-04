import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/data/models/enums/role.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/repositories/session_storage.dart';
import 'package:mostro_mobile/features/key_manager/key_manager.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';
import 'package:sembast/sembast_memory.dart';

import '../mocks.mocks.dart';

/// SessionStorage whose pending-child write always fails, to exercise the
/// persistence error path of createChildOrderSession.
class _FailingPendingChildStorage extends SessionStorage {
  _FailingPendingChildStorage(super.keyManager, {required super.db});

  @override
  Future<void> putPendingChildSession(Session session) async {
    throw StateError('disk full');
  }
}

/// SessionStorage whose promotion always fails, to exercise the durable-first
/// ordering of linkChildSessionToOrderId.
class _FailingPromotionStorage extends SessionStorage {
  _FailingPromotionStorage(super.keyManager, {required super.db});

  @override
  Future<void> promotePendingChildSession(Session session) async {
    throw StateError('disk full');
  }
}

void main() {
  late MockRef mockRef;
  late MockKeyManager mockKeyManager;
  late SessionStorage storage;

  // Dummy private keys for testing purposes only
  final masterKey = NostrKeyPairs(
    private: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
  );
  final childTradeKey = NostrKeyPairs(
    private: 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
  );
  const childKeyIndex = 5;

  Settings buildSettings({int? sessionExpirationHours}) => Settings(
        relays: [],
        fullPrivacyMode: false,
        mostroPublicKey: 'test',
        defaultFiatCode: 'USD',
        selectedLanguage: null,
        sessionExpirationHours: sessionExpirationHours,
      );

  SessionNotifier buildNotifier({int? sessionExpirationHours}) =>
      SessionNotifier(
        mockRef,
        storage,
        buildSettings(sessionExpirationHours: sessionExpirationHours),
      );

  /// Rewrites the persisted pending child record with an older start time,
  /// simulating a record that has been sitting on disk for [age].
  Future<void> agePendingChildRecord(Duration age) async {
    final key =
        '${SessionStorage.pendingChildKeyPrefix}${childTradeKey.public}';
    final stored = await storage.store.record(key).get(storage.db);
    final aged = Map<String, dynamic>.from(stored!)
      ..['start_time'] = DateTime.now().subtract(age).toIso8601String();
    await storage.store.record(key).put(storage.db, aged);
  }

  setUpAll(() {
    provideDummy<KeyManager>(MockKeyManager());
  });

  setUp(() async {
    mockRef = MockRef();
    mockKeyManager = MockKeyManager();

    when(mockRef.read(keyManagerProvider)).thenReturn(mockKeyManager);
    when(mockKeyManager.masterKeyPair).thenReturn(masterKey);
    when(mockKeyManager.deriveTradeKeyPair(childKeyIndex))
        .thenReturn(childTradeKey);

    final db = await newDatabaseFactoryMemory().openDatabase('sessions-test');
    storage = SessionStorage(mockKeyManager, db: db);
  });

  group('createChildOrderSession persistence', () {
    test('persists the pending child session to storage', () async {
      // Arrange
      final notifier = buildNotifier();

      // Act
      await notifier.createChildOrderSession(
        tradeKey: childTradeKey,
        keyIndex: childKeyIndex,
        parentOrderId: 'parent-order-id',
        role: Role.seller,
      );

      // Assert: the record is on disk, so the background isolate (which
      // loads sessions from storage) can decrypt events addressed to the
      // child trade key.
      final stored = await storage.getAllSessions();
      expect(stored, hasLength(1));
      expect(stored.first.orderId, isNull);
      expect(stored.first.parentOrderId, 'parent-order-id');
      expect(stored.first.tradeKey.public, childTradeKey.public);
    });

    test('restores the pending child session after an app restart', () async {
      // Arrange: a pending child exists, then the app is killed
      final notifier = buildNotifier();
      await notifier.createChildOrderSession(
        tradeKey: childTradeKey,
        keyIndex: childKeyIndex,
        parentOrderId: 'parent-order-id',
        role: Role.seller,
      );

      // Act: a fresh notifier over the same storage simulates the restart
      final restarted = buildNotifier();
      await restarted.init();

      // Assert
      final restored = restarted.state
          .where((s) => s.tradeKey.public == childTradeKey.public)
          .toList();
      expect(restored, hasLength(1));
      expect(restored.first.orderId, isNull);
      expect(restored.first.parentOrderId, 'parent-order-id');
    });

    test('drops an expired pending child session on init', () async {
      // Arrange: persist a pending child, then age it beyond expiration
      final notifier = buildNotifier();
      await notifier.createChildOrderSession(
        tradeKey: childTradeKey,
        keyIndex: childKeyIndex,
        parentOrderId: 'parent-order-id',
        role: Role.seller,
      );
      await agePendingChildRecord(const Duration(hours: 3));

      // Act: restart with a 1-hour expiration window
      final restarted = buildNotifier(sessionExpirationHours: 1);
      await restarted.init();

      // Assert: not restored and removed from storage
      expect(restarted.state, isEmpty);
      expect(await storage.getAllSessions(), isEmpty);
    });
  });

  group('linkChildSessionToOrderId persistence', () {
    test('re-stores the session under its orderId and drops the pending one',
        () async {
      // Arrange
      final notifier = buildNotifier();
      await notifier.createChildOrderSession(
        tradeKey: childTradeKey,
        keyIndex: childKeyIndex,
        parentOrderId: 'parent-order-id',
        role: Role.seller,
      );

      // Act
      await notifier.linkChildSessionToOrderId(
        'child-order-id',
        childTradeKey.public,
      );

      // Assert: a single record remains, keyed by the child order id
      final stored = await storage.getAllSessions();
      expect(stored, hasLength(1));
      expect(stored.first.orderId, 'child-order-id');
      expect(await storage.getSession('child-order-id'), isNotNull);
    });

    test('links a pending child restored after an app restart', () async {
      // Arrange: pending child created, app killed, app restarted
      final notifier = buildNotifier();
      await notifier.createChildOrderSession(
        tradeKey: childTradeKey,
        keyIndex: childKeyIndex,
        parentOrderId: 'parent-order-id',
        role: Role.seller,
      );
      final restarted = buildNotifier();
      await restarted.init();

      // Act: the child new-order message arrives after the restart
      await restarted.linkChildSessionToOrderId(
        'child-order-id',
        childTradeKey.public,
      );

      // Assert
      expect(
        restarted.getSessionByOrderId('child-order-id'),
        isNotNull,
      );
      final stored = await storage.getAllSessions();
      expect(stored, hasLength(1));
      expect(stored.first.orderId, 'child-order-id');
    });
  });

  group('linkChildSessionToOrderId durability', () {
    test('keeps the session pending when the promotion fails', () async {
      // Arrange: create through a working storage so the pending record
      // exists, then link through a storage whose promotion fails.
      final creator = buildNotifier();
      await creator.createChildOrderSession(
        tradeKey: childTradeKey,
        keyIndex: childKeyIndex,
        parentOrderId: 'parent-order-id',
        role: Role.seller,
      );
      final failingStorage = _FailingPromotionStorage(
        mockKeyManager,
        db: storage.db,
      );
      final notifier = SessionNotifier(mockRef, failingStorage, buildSettings());
      await notifier.init();
      expect(notifier.getSessionByTradeKey(childTradeKey.public), isNotNull);

      // Act
      Future<void> link() => notifier.linkChildSessionToOrderId(
            'child-order-id',
            childTradeKey.public,
          );

      // Assert: the failure is propagated and nothing moved in memory, so a
      // later message for the child can retry the link.
      await expectLater(link, throwsStateError);
      final pending = notifier.getSessionByTradeKey(childTradeKey.public);
      expect(pending, isNotNull);
      expect(pending!.orderId, isNull);
      expect(notifier.getSessionByOrderId('child-order-id'), isNull);
      expect(notifier.state.where((s) => s.orderId == 'child-order-id'),
          isEmpty);
      final pendingKey =
          '${SessionStorage.pendingChildKeyPrefix}${childTradeKey.public}';
      expect(await storage.store.record(pendingKey).exists(storage.db), isTrue);
    });
  });

  group('pending child bounded lifetime', () {
    test('keeps a pending child when session expiration is disabled', () async {
      // Arrange: expiration disabled (0 == forever) and an old-ish record
      final notifier = buildNotifier(sessionExpirationHours: 0);
      await notifier.createChildOrderSession(
        tradeKey: childTradeKey,
        keyIndex: childKeyIndex,
        parentOrderId: 'parent-order-id',
        role: Role.seller,
      );
      await agePendingChildRecord(const Duration(hours: 3));

      // Act
      final restarted = buildNotifier(sessionExpirationHours: 0);
      await restarted.init();

      // Assert
      expect(restarted.state, hasLength(1));
      expect(await storage.getAllSessions(), hasLength(1));
    });

    test('drops a pending child past its own TTL even with expiration disabled',
        () async {
      // Arrange: a pending child that was never linked. With expiration
      // disabled it would otherwise stay on disk (and in the orders filter)
      // forever, so the bounded TTL has to apply on its own.
      final notifier = buildNotifier(sessionExpirationHours: 0);
      await notifier.createChildOrderSession(
        tradeKey: childTradeKey,
        keyIndex: childKeyIndex,
        parentOrderId: 'parent-order-id',
        role: Role.seller,
      );
      await agePendingChildRecord(
        Duration(hours: Config.pendingChildSessionExpirationHours + 1),
      );

      // Act
      final restarted = buildNotifier(sessionExpirationHours: 0);
      await restarted.init();

      // Assert
      expect(restarted.state, isEmpty);
      expect(await storage.getAllSessions(), isEmpty);
    });

    test('drops a stored record with neither orderId nor parentOrderId',
        () async {
      // Arrange: only pending children are stored without an orderId; any
      // other such record can never be linked.
      final notifier = buildNotifier();
      await notifier.createChildOrderSession(
        tradeKey: childTradeKey,
        keyIndex: childKeyIndex,
        parentOrderId: 'parent-order-id',
        role: Role.seller,
      );
      final key =
          '${SessionStorage.pendingChildKeyPrefix}${childTradeKey.public}';
      final stored = await storage.store.record(key).get(storage.db);
      await storage.store.record(key).put(
            storage.db,
            Map<String, dynamic>.from(stored!)..['parent_order_id'] = null,
          );

      // Act
      final restarted = buildNotifier();
      await restarted.init();

      // Assert
      expect(restarted.state, isEmpty);
      expect(await storage.getAllSessions(), isEmpty);
    });

    test('saveSession drops the pending record once the order id is known',
        () async {
      // Arrange
      final notifier = buildNotifier();
      final session = await notifier.createChildOrderSession(
        tradeKey: childTradeKey,
        keyIndex: childKeyIndex,
        parentOrderId: 'parent-order-id',
        role: Role.seller,
      );

      // Act: the child session is saved through the generic path instead of
      // linkChildSessionToOrderId
      session.orderId = 'child-order-id';
      await notifier.saveSession(session);

      // Assert
      final stored = await storage.getAllSessions();
      expect(stored, hasLength(1));
      expect(stored.first.orderId, 'child-order-id');
    });

    test(
        'createChildOrderSession rethrows a persistence failure and leaves no '
        'pending session behind', () async {
      // Arrange
      final failingStorage = _FailingPendingChildStorage(
        mockKeyManager,
        db: storage.db,
      );
      final notifier =
          SessionNotifier(mockRef, failingStorage, buildSettings());

      // Act
      Future<Session> create() => notifier.createChildOrderSession(
            tradeKey: childTradeKey,
            keyIndex: childKeyIndex,
            parentOrderId: 'parent-order-id',
            role: Role.seller,
          );

      // Assert: the caller must not proceed as if the child were ready
      await expectLater(create, throwsStateError);
      expect(notifier.state, isEmpty);
      expect(notifier.getSessionByTradeKey(childTradeKey.public), isNull);
      expect(await storage.getAllSessions(), isEmpty);
    });
  });

  group('SessionStorage pending child records', () {
    test(
        'promotePendingChildSession stores the session under its orderId and '
        'drops the pending record in one step', () async {
      // Arrange
      final notifier = buildNotifier();
      final session = await notifier.createChildOrderSession(
        tradeKey: childTradeKey,
        keyIndex: childKeyIndex,
        parentOrderId: 'parent-order-id',
        role: Role.seller,
      );
      session.orderId = 'child-order-id';

      // Act
      await storage.promotePendingChildSession(session);

      // Assert
      final pendingKey =
          '${SessionStorage.pendingChildKeyPrefix}${childTradeKey.public}';
      expect(
          await storage.store.record(pendingKey).exists(storage.db), isFalse);
      expect(await storage.store.record('child-order-id').exists(storage.db),
          isTrue);
      expect(await storage.getAllSessions(), hasLength(1));
    });

    test('promotePendingChildSession rejects sessions without an orderId',
        () async {
      final notifier = buildNotifier();
      final session = await notifier.createChildOrderSession(
        tradeKey: childTradeKey,
        keyIndex: childKeyIndex,
        parentOrderId: 'parent-order-id',
        role: Role.seller,
      );

      expect(
        () => storage.promotePendingChildSession(session),
        throwsArgumentError,
      );
      // The pending record is untouched by a rejected promotion.
      expect(await storage.getAll(), hasLength(1));
    });

    test('putPendingChildSession rejects sessions that have an orderId',
        () async {
      final notifier = buildNotifier();
      final session = await notifier.createChildOrderSession(
        tradeKey: childTradeKey,
        keyIndex: childKeyIndex,
        parentOrderId: 'parent-order-id',
        role: Role.seller,
      );
      session.orderId = 'some-order-id';

      expect(
        () => storage.putPendingChildSession(session),
        throwsArgumentError,
      );
    });

    test('getAll includes pending child sessions for the background isolate',
        () async {
      // Arrange
      final notifier = buildNotifier();
      await notifier.createChildOrderSession(
        tradeKey: childTradeKey,
        keyIndex: childKeyIndex,
        parentOrderId: 'parent-order-id',
        role: Role.seller,
      );

      // Act: getAll() is what _loadSessionsFromDatabase uses in the
      // background isolate to match events by trade key.
      final all = await storage.getAll();

      // Assert
      expect(
        all.any((s) => s.tradeKey.public == childTradeKey.public),
        isTrue,
      );
    });
  });
}
