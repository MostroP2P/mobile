import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/data/models/enums/role.dart';
import 'package:mostro_mobile/features/key_manager/key_manager.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';

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
}
