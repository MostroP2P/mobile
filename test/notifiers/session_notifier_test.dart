import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/enums/role.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/features/key_manager/key_manager.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/repositories/mostro_storage.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';

import '../mocks.mocks.dart';

void main() {
  late MockRef mockRef;
  late MockKeyManager mockKeyManager;
  late MockSessionStorage mockStorage;
  late MockPushNotificationService mockPushService;
  late SessionNotifier notifier;

  // Dummy private keys for testing purposes only
  final masterKey = NostrKeyPairs(
    private:
        '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
  );
  final childTradeKey = NostrKeyPairs(
    private:
        'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
  );
  final derivedTradeKey = NostrKeyPairs(
    private:
        '0fedcba9876543210fedcba9876543210fedcba9876543210fedcba987654321',
  );

  setUpAll(() {
    provideDummy<KeyManager>(MockKeyManager());
    provideDummy<MostroStorage>(MockMostroStorage());
  });

  setUp(() {
    mockRef = MockRef();
    mockKeyManager = MockKeyManager();
    mockStorage = MockSessionStorage();
    mockPushService = MockPushNotificationService();

    when(mockRef.read(keyManagerProvider)).thenReturn(mockKeyManager);
    when(mockKeyManager.masterKeyPair).thenReturn(masterKey);
    when(mockPushService.registerToken(any)).thenAnswer((_) async => true);
    when(mockStorage.putSession(any)).thenAnswer((_) async {});
    when(mockKeyManager.getCurrentKeyIndex()).thenAnswer((_) async => 1);
    when(mockKeyManager.deriveTradeKey())
        .thenAnswer((_) async => derivedTradeKey);
    when(mockStorage.putPendingChildSession(any)).thenAnswer((_) async {});
    when(mockStorage.deletePendingChildSession(any)).thenAnswer((_) async {});
    when(mockStorage.promotePendingChildSession(any)).thenAnswer((_) async {});

    notifier = SessionNotifier(
      mockRef,
      mockStorage,
      Settings(
        relays: [],
        fullPrivacyMode: false,
        mostroPublicKey: 'test',
        defaultFiatCode: 'USD',
        selectedLanguage: null,
      ),
    );
    notifier.setPushNotificationService(mockPushService);
  });

  group('createChildOrderSession', () {
    test('registers push token for the child trade key', () async {
      // Act
      await notifier.createChildOrderSession(
        tradeKey: childTradeKey,
        keyIndex: 5,
        parentOrderId: 'parent-order-id',
        role: Role.seller,
      );

      // Assert: the child trade key is registered with the push server so
      // FCM can wake the device when the child order is taken.
      await untilCalled(mockPushService.registerToken(childTradeKey.public));
      verify(mockPushService.registerToken(childTradeKey.public)).called(1);
    });

    test('keeps the child session pending in state without an orderId',
        () async {
      // Act
      final session = await notifier.createChildOrderSession(
        tradeKey: childTradeKey,
        keyIndex: 5,
        parentOrderId: 'parent-order-id',
        role: Role.seller,
      );

      // Assert
      expect(session.orderId, isNull);
      expect(session.parentOrderId, 'parent-order-id');
      expect(
        notifier.state.any((s) => s.tradeKey.public == childTradeKey.public),
        isTrue,
      );
    });
  });

  group('linkChildSessionToOrderId', () {
    test('re-registers push token when linking the child order', () async {
      // Arrange: a pending child session exists
      await notifier.createChildOrderSession(
        tradeKey: childTradeKey,
        keyIndex: 5,
        parentOrderId: 'parent-order-id',
        role: Role.seller,
      );
      await untilCalled(mockPushService.registerToken(childTradeKey.public));
      clearInteractions(mockPushService);

      // Act
      await notifier.linkChildSessionToOrderId(
        'child-order-id',
        childTradeKey.public,
      );

      // Assert: linking retries the registration (idempotent server-side),
      // covering a failed creation-time attempt (e.g. offline after release).
      await untilCalled(mockPushService.registerToken(childTradeKey.public));
      verify(mockPushService.registerToken(childTradeKey.public)).called(1);
      expect(
        notifier.state.any((s) => s.orderId == 'child-order-id'),
        isTrue,
      );
    });

    test('does not register token when no pending child session exists',
        () async {
      // Act
      await notifier.linkChildSessionToOrderId(
        'child-order-id',
        childTradeKey.public,
      );

      // Assert
      verifyNever(mockPushService.registerToken(any));
    });
  });

  group('duplicate order sessions', () {
    Session buildSession(String orderId, NostrKeyPairs tradeKey) => Session(
          masterKey: masterKey,
          tradeKey: tradeKey,
          keyIndex: 7,
          fullPrivacy: false,
          startTime: DateTime.now(),
          orderId: orderId,
          role: Role.seller,
        );

    test(
        'saveSession drops a stale request session that already carries the '
        'same orderId', () async {
      // Arrange: a pending create-order session (keyed by requestId) that has
      // already been assigned its orderId by Mostro's newOrder response.
      final pending = await notifier.newSession(requestId: 42, role: Role.seller);
      pending.orderId = 'order-1';

      // Act: a *different* Session object for the same order is persisted,
      // as the restore flow does (it rebuilds sessions from scratch).
      await notifier.saveSession(buildSession('order-1', childTradeKey));

      // Assert: the order appears exactly once in the emitted state.
      expect(
        notifier.state.where((s) => s.orderId == 'order-1').length,
        1,
      );
    });

    test(
        'linkChildSessionToOrderId drops a stale session that already carries '
        'the same orderId', () async {
      // Arrange: an order already known by requestId that resolved to
      // 'child-order-id', plus a pending child session for the same order.
      final pending = await notifier.newSession(requestId: 7, role: Role.seller);
      pending.orderId = 'child-order-id';
      await notifier.createChildOrderSession(
        tradeKey: childTradeKey,
        keyIndex: 5,
        parentOrderId: 'parent-order-id',
        role: Role.seller,
      );

      // Act
      await notifier.linkChildSessionToOrderId(
        'child-order-id',
        childTradeKey.public,
      );

      // Assert
      expect(
        notifier.state.where((s) => s.orderId == 'child-order-id').length,
        1,
      );
    });

    test('registerSessionInMemory never emits the same orderId twice',
        () async {
      // Arrange
      final pending = await notifier.newSession(requestId: 9, role: Role.seller);
      pending.orderId = 'order-2';

      // Act
      notifier.registerSessionInMemory(buildSession('order-2', childTradeKey));

      // Assert
      expect(
        notifier.state.where((s) => s.orderId == 'order-2').length,
        1,
      );
    });
  });

  group('syncPushRegistrations', () {
    late MockMostroStorage mockMostroStorage;

    final liveKey = NostrKeyPairs(
      private:
          '1111111111111111111111111111111111111111111111111111111111111111',
    );
    final finishedKey = NostrKeyPairs(
      private:
          '2222222222222222222222222222222222222222222222222222222222222222',
    );
    final recentlyFinishedKey = NostrKeyPairs(
      private:
          '3333333333333333333333333333333333333333333333333333333333333333',
    );
    final unknownKey = NostrKeyPairs(
      private:
          '4444444444444444444444444444444444444444444444444444444444444444',
    );

    Session sessionFor(String orderId, NostrKeyPairs tradeKey) => Session(
          masterKey: masterKey,
          tradeKey: tradeKey,
          keyIndex: 3,
          fullPrivacy: false,
          startTime: DateTime.now(),
          orderId: orderId,
          role: Role.seller,
        );

    MostroMessage messageAt(Action action, Duration age) => MostroMessage(
          action: action,
          id: 'x',
          timestamp: DateTime.now().subtract(age).millisecondsSinceEpoch,
        );

    setUp(() {
      mockMostroStorage = MockMostroStorage();
      when(mockRef.read(mostroStorageProvider)).thenReturn(mockMostroStorage);
      when(mockPushService.isPushEnabledInSettings).thenReturn(() => true);
      when(mockPushService.registerTokens(any))
          .thenAnswer((inv) async => (inv.positionalArguments[0] as List).length);
      when(mockPushService.unregisterTokens(any)).thenAnswer((_) async {});

      when(mockMostroStorage.getLatestMessageById('live'))
          .thenAnswer((_) async => messageAt(Action.fiatSentOk, Duration.zero));
      when(mockMostroStorage.getLatestMessageById('finished')).thenAnswer(
          (_) async => messageAt(Action.purchaseCompleted, const Duration(days: 3)));
      when(mockMostroStorage.getLatestMessageById('recently-finished'))
          .thenAnswer((_) async =>
              messageAt(Action.canceled, const Duration(hours: 2)));
      when(mockMostroStorage.getLatestMessageById('unknown'))
          .thenAnswer((_) async => null);

      notifier.registerSessionInMemory(sessionFor('live', liveKey));
      notifier.registerSessionInMemory(sessionFor('finished', finishedKey));
      notifier.registerSessionInMemory(
          sessionFor('recently-finished', recentlyFinishedKey));
      notifier.registerSessionInMemory(sessionFor('unknown', unknownKey));
    });

    List<String> registeredKeys() {
      final captured =
          verify(mockPushService.registerTokens(captureAny)).captured;
      return (captured.last as List).cast<String>();
    }

    test('registers live trades and skips ones finished past the grace period',
        () async {
      await notifier.syncPushRegistrations(force: true);

      expect(
        registeredKeys(),
        unorderedEquals([
          liveKey.public,
          recentlyFinishedKey.public,
          unknownKey.public,
        ]),
      );
    });

    test('includes pending range-order children', () async {
      await notifier.createChildOrderSession(
        tradeKey: childTradeKey,
        keyIndex: 5,
        parentOrderId: 'parent-order-id',
        role: Role.seller,
      );

      await notifier.syncPushRegistrations(force: true);

      expect(registeredKeys(), contains(childTradeKey.public));
    });

    test('throttles unforced calls but not forced ones', () async {
      await notifier.syncPushRegistrations();
      await notifier.syncPushRegistrations();
      verify(mockPushService.registerTokens(any)).called(1);

      await notifier.syncPushRegistrations(force: true);
      verify(mockPushService.registerTokens(any)).called(1);
    });

    test('retries on the next call after a partial failure', () async {
      when(mockPushService.registerTokens(any)).thenAnswer((_) async => 0);

      await notifier.syncPushRegistrations();
      await notifier.syncPushRegistrations();

      verify(mockPushService.registerTokens(any)).called(2);
    });

    test('does nothing while push notifications are disabled', () async {
      when(mockPushService.isPushEnabledInSettings).thenReturn(() => false);

      await notifier.syncPushRegistrations(force: true);

      verifyNever(mockPushService.registerTokens(any));
    });

    test('unregisterPushTokens drops every trade, finished ones included',
        () async {
      await notifier.unregisterPushTokens();

      final captured =
          verify(mockPushService.unregisterTokens(captureAny)).captured;
      expect(
        (captured.single as List).cast<String>(),
        unorderedEquals([
          liveKey.public,
          finishedKey.public,
          recentlyFinishedKey.public,
          unknownKey.public,
        ]),
      );
    });
  });
}
