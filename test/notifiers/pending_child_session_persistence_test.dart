import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/data/models/enums/role.dart';
import 'package:mostro_mobile/data/repositories/session_storage.dart';
import 'package:mostro_mobile/features/key_manager/key_manager.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';
import 'package:sembast/sembast_memory.dart';

import '../mocks.mocks.dart';

void main() {
  late MockRef mockRef;
  late MockKeyManager mockKeyManager;
  late SessionStorage storage;

  // Dummy private keys for testing purposes only
  final masterKey = NostrKeyPairs(
    private:
        '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
  );
  final childTradeKey = NostrKeyPairs(
    private:
        'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
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
      final session = await notifier.createChildOrderSession(
        tradeKey: childTradeKey,
        keyIndex: childKeyIndex,
        parentOrderId: 'parent-order-id',
        role: Role.seller,
      );
      final aged = session.toJson()
        ..['start_time'] = DateTime.now()
            .subtract(const Duration(hours: 3))
            .toIso8601String();
      await storage.store
          .record(
            '${SessionStorage.pendingChildKeyPrefix}${childTradeKey.public}',
          )
          .put(storage.db, aged);

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

  group('SessionStorage pending child records', () {
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
