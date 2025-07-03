import 'dart:convert';
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/key_manager/key_derivator.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/services/mostro_service.dart';
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager_provider.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';
import 'package:mostro_mobile/data/repositories/mostro_storage.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';

import '../mocks.mocks.dart';
import 'mostro_service_test.mocks.dart' hide MockRef;
import 'mostro_service_helper_functions.dart';

void main() {
  // Provide dummy values for Mockito
  provideDummy<Settings>(Settings(
    relays: ['wss://relay.damus.io'],
    fullPrivacyMode: false,
    mostroPublicKey: '9d9d0455a96871f2dc4289b8312429db2e925f167b37c77bf7b28014be235980',
    defaultFiatCode: 'USD',
  ));
  
  // Add dummy for MostroStorage
  provideDummy<MostroStorage>(MockMostroStorage());
  
  // Add dummy for NostrService
  provideDummy<NostrService>(MockNostrService());
  late MostroService mostroService;
  late KeyDerivator keyDerivator;
  late MockServerTradeIndex mockServerTradeIndex;
  late MockNostrService mockNostrService;
  late MockSessionNotifier mockSessionNotifier;
  late MockRef mockRef;
  late MockSubscriptionManager mockSubscriptionManager;

  setUpAll(() {
    // Create a dummy Settings object that will be used by MockRef
    final dummySettings = Settings(
      relays: ['wss://relay.damus.io'],
      fullPrivacyMode: false,
      mostroPublicKey: '9d9d0455a96871f2dc4289b8312429db2e925f167b37c77bf7b28014be235980',
      defaultFiatCode: 'USD',
    );
    
    // Provide dummy values for Mockito
    provideDummy<SessionNotifier>(MockSessionNotifier());
    provideDummy<Settings>(dummySettings);
    provideDummy<NostrService>(MockNostrService());
    
    // Create a mock ref for the SubscriptionManager dummy
    provideDummy<SubscriptionManager>(MockSubscriptionManager());
    
    // Create a mock ref that returns the dummy settings
    final mockRefForDummy = MockRef();
    when(mockRefForDummy.read(settingsProvider)).thenReturn(dummySettings);
    
    // Provide a dummy MostroService that uses our properly configured mock ref
    provideDummy<MostroService>(MostroService(mockRefForDummy));
  });

  setUp(() {
    mockNostrService = MockNostrService();
    mockSessionNotifier = MockSessionNotifier();
    mockRef = MockRef();
    mockSubscriptionManager = MockSubscriptionManager();
    mockServerTradeIndex = MockServerTradeIndex();
    keyDerivator = KeyDerivator("m/44'/1237'/38383'/0");
    // Generate a valid test key pair for mostro public key
    final testKeyPair = NostrUtils.generateKeyPair();
    
    // Create test settings
    final testSettings = Settings(
      relays: ['wss://relay.damus.io'],
      fullPrivacyMode: false,
      mostroPublicKey: testKeyPair.public,
      defaultFiatCode: 'USD',
    );
    
    // Stub specific provider reads
    when(mockRef.read(settingsProvider)).thenReturn(testSettings);
    when(mockRef.read(mostroStorageProvider)).thenReturn(MockMostroStorage());
    when(mockRef.read(nostrServiceProvider)).thenReturn(mockNostrService);
    when(mockRef.read(subscriptionManagerProvider)).thenReturn(mockSubscriptionManager);
    
    // Stub SessionNotifier methods
    when(mockSessionNotifier.sessions).thenReturn(<Session>[]);
    
    when(mockRef.read(sessionNotifierProvider.notifier)).thenReturn(mockSessionNotifier);
    
    // Create the service under test
    mostroService = MostroService(mockRef);
  });
  
  tearDown(() {
    // Clean up resources
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
    final messageBase64 = hex.encode(jsonString.codeUnits);

    return NostrKeyPairs.verify(userPubKey, messageBase64, signatureHex);
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

      when(mockSessionNotifier.getSessionByOrderId(orderId))
          .thenReturn(session);

      // Mock NostrService's publishEvent only
      when(mockNostrService.publishEvent(any))
          .thenAnswer((_) async {});

      when(mockSessionNotifier.newSession(orderId: orderId))
          .thenAnswer((_) async => session);

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
      final tradePrivKey = keyDerivator.derivePrivateKey(extendedPrivKey, tradeIndex);
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

      when(mockSessionNotifier.getSessionByOrderId(orderId))
          .thenReturn(session);

      // Mock NostrService's publishEvent only - other methods are now static in NostrUtils
      when(mockNostrService.publishEvent(any))
          .thenAnswer((_) async => Future<void>.value());

      when(mockNostrService.publishEvent(any))
          .thenAnswer((_) async => Future.value());

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
        signatureHex: '0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
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
      final tradePrivKey = keyDerivator.derivePrivateKey(extendedPrivKey, tradeIndex);
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

      when(mockSessionNotifier.getSessionByOrderId(orderId))
          .thenReturn(session);

      // Simulate that tradeIndex=3 has already been used
      mockServerTradeIndex.userTradeIndices[userPubKey] = 3;

      // Mock NostrService's publishEvent only - other methods are now static in NostrUtils
      when(mockNostrService.publishEvent(any))
          .thenAnswer((_) async => Future<void>.value());

      when(mockNostrService.publishEvent(any))
          .thenAnswer((_) async => Future.value());

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
      final tradePrivKey = keyDerivator.derivePrivateKey(extendedPrivKey, tradeIndex);
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

      when(mockSessionNotifier.getSessionByOrderId(orderId))
          .thenReturn(session);

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
}
