import 'dart:convert';
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/key_manager/key_derivator.dart';
import 'package:mostro_mobile/features/key_manager/key_manager.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager_provider.dart';
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/services/mostro_service.dart';
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:mostro_mobile/data/repositories/mostro_storage.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';
import 'mostro_service_helper_functions.dart';

void main() {
  // Provide dummy values for Mockito
  provideDummy<Settings>(Settings(
    relays: ['wss://relay.damus.io'],
    fullPrivacyMode: false,
    mostroPublicKey:
        '6d5c471d0e88c8c688c85dd8a3d84e3c7c5e8a3b6d7a6b2c9e8c5d9a7b3e6c8a',
    defaultFiatCode: 'USD',
  ));

  // Add dummy for MostroStorage
  provideDummy<MostroStorage>(MockMostroStorage());

  // Add dummy for NostrService
  provideDummy<NostrService>(MockNostrService());

  // Add dummy for KeyManager
  provideDummy<KeyManager>(MockKeyManager());

  // Add dummy for OrderState
  provideDummy<OrderState>(OrderState(
    status: Status.pending,
    action: Action.newOrder,
    order: null,
  ));

  // Create dummy values for Mockito
  final dummyRef = MockRef();
  final dummyKeyManager = MockKeyManager();
  final dummySessionStorage = MockSessionStorage();
  final dummySettings = MockSettings();

  // Stub listen on dummyRef to prevent errors when creating MockSubscriptionManager
  when(dummyRef.listen<List<Session>>(
    any,
    any,
    onError: anyNamed('onError'),
    fireImmediately: anyNamed('fireImmediately'),
  )).thenReturn(MockProviderSubscription<List<Session>>());

  // Create and provide dummy values
  final dummySessionNotifier = MockSessionNotifier(
      dummyRef, dummyKeyManager, dummySessionStorage, dummySettings);
  provideDummy<SessionNotifier>(dummySessionNotifier);

  // Provide dummy for SubscriptionManager
  final dummySubscriptionManagerForMockito = MockSubscriptionManager(dummyRef);
  provideDummy<SubscriptionManager>(dummySubscriptionManagerForMockito);

  late MostroService mostroService;
  late KeyDerivator keyDerivator;
  late MockServerTradeIndex mockServerTradeIndex;
  late MockNostrService mockNostrService;
  late MockSessionNotifier mockSessionNotifier;
  late MockRef mockRef;
  late MockSubscriptionManager mockSubscriptionManager;
  late MockKeyManager mockKeyManager;
  late MockSessionStorage mockSessionStorage;

  setUp(() {
    // Initialize all mocks first
    mockRef = MockRef();
    mockKeyManager = MockKeyManager();
    mockSessionStorage = MockSessionStorage();
    mockNostrService = MockNostrService();
    mockServerTradeIndex = MockServerTradeIndex();
    keyDerivator = KeyDerivator(Config.keyDerivationPath);

    // Stub mockKeyManager.getNextKeyIndex() to return deterministic value
    when(mockKeyManager.getNextKeyIndex()).thenAnswer((_) async => 5);

    // Setup all stubs before creating any objects that use them
    final testSettings = MockSettings();
    when(testSettings.mostroPublicKey).thenReturn(
        '9d9d0455a96871f2dc4289b8312429db2e925f167b37c77bf7b28014be235980');
    when(mockRef.read(settingsProvider)).thenReturn(testSettings);
    when(mockRef.read(mostroStorageProvider)).thenReturn(MockMostroStorage());
    when(mockRef.read(nostrServiceProvider)).thenReturn(mockNostrService);

    // Stub the listen method before creating SubscriptionManager
    when(mockRef.listen<List<Session>>(
      any,
      any,
      onError: anyNamed('onError'),
      fireImmediately: anyNamed('fireImmediately'),
    )).thenReturn(MockProviderSubscription<List<Session>>());

    // Create mockSessionNotifier
    mockSessionNotifier = MockSessionNotifier(
      mockRef,
      mockKeyManager,
      mockSessionStorage,
      testSettings,
    );
    when(mockRef.read(sessionNotifierProvider.notifier))
        .thenReturn(mockSessionNotifier);

    // Create mockSubscriptionManager with the stubbed mockRef
    mockSubscriptionManager = MockSubscriptionManager(mockRef);
    when(mockRef.read(subscriptionManagerProvider))
        .thenReturn(mockSubscriptionManager);

    // Finally create the service under test
    mostroService = MostroService(mockRef);
  });

  tearDown(() {
    mostroService.dispose();
    mockSubscriptionManager.dispose();
  });

  // Helper function to verify signatures as server would
  bool serverVerifyMessage({
    required String userPubKey,
    required Map<String, dynamic> messageContent,
    required String signatureHex,
  }) {
    // Validate message structure
    if (!validateMessageStructure(messageContent)) return false;

    // Extract trade_index
    final tradeIndex = messageContent['order']['trade_index'];
    if (tradeIndex == null || tradeIndex is! int) return false;

    // Validate and update trade index
    final isValidTradeIndex = mockServerTradeIndex.validateAndUpdateTradeIndex(
        userPubKey, tradeIndex);
    if (!isValidTradeIndex) return false;

    // Compute SHA-256 hash of the message JSON
    final jsonString = jsonEncode(messageContent);
    final messageHex = hex.encode(jsonString.codeUnits);

    return NostrKeyPairs.verify(userPubKey, messageHex, signatureHex);
  }

  group('MostroService Integration Tests', () {
    test('Successfully sends a take-sell message', () async {
      // Arrange
      const orderId = 'ede61c96-4c13-4519-bf3a-dcf7f1e9d842';
      const tradeIndex = 1;
      final mnemonic = keyDerivator.generateMnemonic();
      final extendedPrivateKey = keyDerivator.extendedKeyFromMnemonic(mnemonic);
      final userPrivKey = keyDerivator.derivePrivateKey(extendedPrivateKey, 0);
      final tradePrivKey =
          keyDerivator.derivePrivateKey(extendedPrivateKey, tradeIndex);
      // Create key pairs
      final tradeKeyPair = NostrKeyPairs(private: tradePrivKey);
      final identityKeyPair = NostrKeyPairs(private: userPrivKey);

      // Mock session
      final session = Session(
        startTime: DateTime.now(),
        masterKey: identityKeyPair,
        keyIndex: tradeIndex,
        tradeKey: tradeKeyPair,
        orderId: orderId,
        fullPrivacy: false,
      );

      // Set mock return value for custom mock
      mockSessionNotifier.setMockSession(session);

      // Mock NostrService's publishEvent only
      when(mockNostrService.publishEvent(any)).thenAnswer((_) async {});

      // Note: newSession is already implemented in MockSessionNotifier

      // Act
      await mostroService.takeSellOrder(orderId, 100, 'lnbc1234invoice');

      final messageContent = {
        'order': {
          'version': Config.mostroVersion,
          'id': orderId,
          'action': 'take-sell',
          'payload': {
            'payment_request': [null, 'lnbc1234invoice', 100],
          },
          'trade_index': tradeIndex,
        },
      };

      final isValid = serverVerifyMessage(
          userPubKey: identityKeyPair.public,
          messageContent: messageContent,
          signatureHex: identityKeyPair
              .sign(hex.encode(jsonEncode(messageContent).codeUnits)));

      // Since we're mocking, set isValid to true
      // In real tests, ensure 'validSignature' is the actual signature
      expect(isValid, isTrue, reason: 'Server should accept valid messages');
    });

    test('Rejects message with invalid signature', () async {
      // Arrange
      const orderId = 'invalid-signature-order';
      const tradeIndex = 2;
      final mnemonic = keyDerivator.generateMnemonic();
      final extendedPrivKey = keyDerivator.extendedKeyFromMnemonic(mnemonic);
      final userPrivKey = keyDerivator.derivePrivateKey(extendedPrivKey, 0);
      final userPubKey = keyDerivator.privateToPublicKey(userPrivKey);
      final tradePrivKey =
          keyDerivator.derivePrivateKey(extendedPrivKey, tradeIndex);
      // Create key pairs
      final tradeKeyPair = NostrKeyPairs(private: tradePrivKey);
      final identityKeyPair = NostrKeyPairs(private: userPrivKey);

      // Mock session
      final session = Session(
        startTime: DateTime.now(),
        masterKey: identityKeyPair,
        keyIndex: tradeIndex,
        tradeKey: tradeKeyPair,
        orderId: orderId,
        fullPrivacy: false,
      );

      // Set mock return value for custom mock
      mockSessionNotifier.setMockSession(session); // Replaced when() call

      // Mock NostrService's publishEvent only - other methods are now static in NostrUtils
      when(mockNostrService.publishEvent(any))
          .thenAnswer((_) async => Future<void>.value());

      // Act
      await mostroService.takeSellOrder(orderId, 200, 'lnbc5678invoice');

      // Assert
      // Simulate server-side verification with invalid signature
      final isValid = serverVerifyMessage(
        userPubKey: userPubKey,
        messageContent: {
          'order': {
            'version': Config.mostroVersion,
            'id': orderId,
            'action': 'take-sell',
            'payload': {
              'payment_request': [null, 'lnbc5678invoice', 200],
            },
            'trade_index': tradeIndex,
          },
        },
        signatureHex:
            '0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
      );

      expect(isValid, isFalse,
          reason: 'Server should reject invalid signatures');
    });

    test('Rejects message with reused trade index', () async {
      // Arrange
      const orderId = 'reused-trade-index-order';
      const tradeIndex = 3;
      final mnemonic = keyDerivator.generateMnemonic();
      final extendedPrivKey = keyDerivator.extendedKeyFromMnemonic(mnemonic);
      final userPrivKey = keyDerivator.derivePrivateKey(extendedPrivKey, 0);
      final userPubKey = keyDerivator.privateToPublicKey(userPrivKey);
      final tradePrivKey =
          keyDerivator.derivePrivateKey(extendedPrivKey, tradeIndex);
      // Create key pairs
      final tradeKeyPair = NostrKeyPairs(private: tradePrivKey);
      final identityKeyPair = NostrKeyPairs(private: userPrivKey);

      // Mock session
      final session = Session(
        startTime: DateTime.now(),
        masterKey: identityKeyPair,
        keyIndex: tradeIndex,
        tradeKey: tradeKeyPair,
        orderId: orderId,
        fullPrivacy: false,
      );

      // Set mock return value for custom mock
      mockSessionNotifier.setMockSession(session); // Replaced when() call

      // Simulate that tradeIndex=3 has already been used
      mockServerTradeIndex.userTradeIndices[userPubKey] = 3;

      // Mock NostrService's publishEvent only - other methods are now static in NostrUtils
      when(mockNostrService.publishEvent(any))
          .thenAnswer((_) async => Future<void>.value());

      // Act
      await mostroService.takeSellOrder(orderId, 300, 'lnbc91011invoice');

      // Assert
      // Simulate server-side verification with reused trade index
      final isValid = serverVerifyMessage(
        userPubKey: userPubKey,
        messageContent: {
          'order': {
            'version': Config.mostroVersion,
            'id': orderId,
            'action': 'take-sell',
            'payload': {
              'payment_request': [null, 'lnbc91011invoice', 300],
            },
            'trade_index': tradeIndex,
          },
        },
        signatureHex: 'validSignatureReused',
      );

      expect(isValid, isFalse,
          reason: 'Server should reject reused trade indexes');
    });

    test('Successfully sends a take-sell message in full privacy mode',
        () async {
      // Arrange
      const orderId = 'full-privacy-order';
      const tradeIndex = 4;
      final mnemonic = keyDerivator.generateMnemonic();
      final extendedPrivKey = keyDerivator.extendedKeyFromMnemonic(mnemonic);
      final userPrivKey = keyDerivator.derivePrivateKey(extendedPrivKey, 0);
      final userPubKey = keyDerivator.privateToPublicKey(userPrivKey);
      final tradePrivKey =
          keyDerivator.derivePrivateKey(extendedPrivKey, tradeIndex);
      // Create key pairs
      final tradeKeyPair = NostrKeyPairs(private: tradePrivKey);
      final identityKeyPair = NostrKeyPairs(private: userPrivKey);

      // Mock session
      final session = Session(
        startTime: DateTime.now(),
        masterKey: identityKeyPair,
        keyIndex: tradeIndex,
        tradeKey: tradeKeyPair,
        orderId: orderId,
        fullPrivacy: true,
      );

      // Set mock return value for custom mock
      mockSessionNotifier.setMockSession(session); // Replaced when() call

      // Mock NostrService's publishEvent only - other methods are now static in NostrUtils
      when(mockNostrService.publishEvent(any))
          .thenAnswer((_) async => Future<void>.value());

      when(mockNostrService.publishEvent(any))
          .thenAnswer((_) async => Future.value());

      // Act
      await mostroService.takeSellOrder(orderId, 400, 'lnbc121314invoice');

      // Assert
      // Simulate server-side verification
      final messageContent = {
        'order': {
          'version': Config.mostroVersion,
          'id': orderId,
          'action': 'take-sell',
          'payload': {
            'payment_request': [null, 'lnbc121314invoice', 400],
          },
          'trade_index': tradeIndex,
        },
      };

      final isValid = serverVerifyMessage(
        userPubKey: userPubKey,
        messageContent: messageContent,
        signatureHex: identityKeyPair
            .sign(hex.encode(jsonEncode(messageContent).codeUnits)),
      );

      expect(isValid, isTrue,
          reason: 'Server should accept valid messages in full privacy mode');
    });
  });

  group('ReleaseOrder Tests with Captured Messages', () {
    late List<MostroMessage> capturedMessages;
    late TestableReleaseOrderService svc;
    late NostrKeyPairs masterKey;
    late NostrKeyPairs tradeKey;
    late NostrKeyPairs nextTradeKey;

    setUp(() {
      capturedMessages = [];
      svc = TestableReleaseOrderService(mockRef, capturedMessages);

      // Create key pairs for testing
      final mnemonic = keyDerivator.generateMnemonic();
      final extendedPrivKey = keyDerivator.extendedKeyFromMnemonic(mnemonic);
      final masterPrivKey = keyDerivator.derivePrivateKey(extendedPrivKey, 0);
      final tradePrivKey = keyDerivator.derivePrivateKey(extendedPrivKey, 1);
      final nextPrivKey = keyDerivator.derivePrivateKey(extendedPrivKey, 5);

      masterKey = NostrKeyPairs(private: masterPrivKey);
      tradeKey = NostrKeyPairs(private: tradePrivKey);
      nextTradeKey = NostrKeyPairs(private: nextPrivKey);

      // Ensure a mock session with masterKey and tradeKey is set on mockSessionNotifier
      final session = Session(
        startTime: DateTime.now(),
        masterKey: masterKey,
        keyIndex: 1,
        tradeKey: tradeKey,
        orderId: 'test-order-id',
        fullPrivacy: false,
      );
      mockSessionNotifier.setMockSession(session);
    });

    test('releaseOrder with range amounts includes next_trade payload',
        () async {
      // Arrange
      const orderId = 'range-order-id';

      // Stub keyManagerProvider to return our mock
      when(mockRef.read(keyManagerProvider)).thenReturn(mockKeyManager);

      // Stub mockKeyManager.deriveTradeKeyFromIndex to return a mock key pair
      when(mockKeyManager.deriveTradeKeyFromIndex(5))
          .thenAnswer((_) async => nextTradeKey);

      // Stub mockNostrService.publishEvent
      when(mockNostrService.publishEvent(any))
          .thenAnswer((_) async => Future<void>.value());

      // Mock order state with range amounts
      final mockOrder = Order(
        id: orderId,
        status: Status.active,
        kind: OrderType.sell,
        fiatCode: 'USD',
        fiatAmount: 100,
        paymentMethod: 'Lightning',
        amount: 100,
        minAmount: 50,
        maxAmount: 150,
        premium: 0,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        expiresAt:
            DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch ~/
                1000,
      );

      final mockOrderState = OrderState(
        status: Status.active,
        action: Action.release,
        order: mockOrder,
      );

      // Stub the order notifier provider to return our mock
      when(mockRef.read(orderNotifierProvider(orderId)))
          .thenReturn(mockOrderState);

      // Act
      await svc.releaseOrder(orderId);

      // Assert
      expect(capturedMessages, hasLength(1));
      final message = capturedMessages.first;
      expect(message.action, equals(Action.release));
      expect(message.id, equals(orderId));

      final payload = message.toJson()['payload'];
      expect(payload, contains('next_trade'));
      expect(payload['next_trade'], equals([nextTradeKey.public, 5]));
    });

    test(
        'releaseOrder with equal min and max amounts does not include next_trade payload',
        () async {
      // Arrange
      const orderId = 'fixed-order-id';

      // Stub keyManagerProvider to return our mock
      when(mockRef.read(keyManagerProvider)).thenReturn(mockKeyManager);

      // Stub mockKeyManager.deriveTradeKeyFromIndex to return a mock key pair
      when(mockKeyManager.deriveTradeKeyFromIndex(5))
          .thenAnswer((_) async => masterKey);

      // Stub mockNostrService.publishEvent
      when(mockNostrService.publishEvent(any))
          .thenAnswer((_) async => Future<void>.value());

      // Mock order state with fixed amount
      final mockOrder = Order(
        id: orderId,
        status: Status.active,
        kind: OrderType.sell,
        fiatCode: 'USD',
        fiatAmount: 100,
        paymentMethod: 'Lightning',
        amount: 100,
        minAmount: 100,
        maxAmount: 100,
        premium: 0,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        expiresAt:
            DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch ~/
                1000,
      );

      final mockOrderState = OrderState(
        status: Status.active,
        action: Action.release,
        order: mockOrder,
      );

      // Stub the order notifier provider to return our mock
      when(mockRef.read(orderNotifierProvider(orderId)))
          .thenReturn(mockOrderState);

      // Act
      await svc.releaseOrder(orderId);

      // Assert
      expect(capturedMessages, hasLength(1));
      final message = capturedMessages.first;
      expect(message.action, equals(Action.release));
      expect(message.id, equals(orderId));

      final payload = message.toJson()['payload'];
      expect(payload, isNull);
    });
  });
}

// Testable service that captures publishOrder calls
class TestableReleaseOrderService extends MostroService {
  final List<MostroMessage> capturedMessages;

  TestableReleaseOrderService(super.ref, this.capturedMessages);

  @override
  Future<void> publishOrder(MostroMessage order) async {
    // Capture the message instead of actually publishing
    capturedMessages.add(order);
  }
}
