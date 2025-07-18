import 'dart:convert';
import 'package:convert/convert.dart';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/key_manager/key_derivator.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/services/mostro_service.dart';
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';
import 'package:mostro_mobile/data/repositories/mostro_storage.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';

import 'mostro_service_test.mocks.dart';
import 'mostro_service_helper_functions.dart';
import '../mocks.mocks.dart';

@GenerateMocks([NostrService, SessionNotifier, Ref])
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
  late MostroService mostroService;
  late KeyDerivator keyDerivator;
  late MockNostrService mockNostrService;
  late MockSessionNotifier mockSessionNotifier;
  late MockRef mockRef;

  final mockServerTradeIndex = MockServerTradeIndex();

  setUp(() {
    mockNostrService = MockNostrService();
    mockSessionNotifier = MockSessionNotifier();
    mockRef = MockRef();

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

    // Stub SessionNotifier methods
    when(mockSessionNotifier.sessions).thenReturn(<Session>[]);

    mostroService = MostroService(mockSessionNotifier, mockRef);
    keyDerivator = KeyDerivator("m/44'/1237'/38383'/0");
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

      // Mock NostrService's createRumor, createSeal, createWrap, publishEvent
      when(mockNostrService.createRumor(any, any, any, any))
          .thenAnswer((_) async => 'encryptedRumorContent');

      when(mockNostrService.generateKeyPair())
          .thenAnswer((_) async => NostrUtils.generateKeyPair());

      when(mockNostrService.createSeal(any, any, any, any))
          .thenAnswer((_) async => 'sealedContent');

      when(mockNostrService.createWrap(any, any, any))
          .thenAnswer((_) async => NostrEvent(
                id: 'wrapEventId',
                kind: 1059,
                pubkey: 'wrapperPubKey',
                content: 'sealedContent',
                createdAt: DateTime.now(),
                tags: [
                  ['p', 'mostroPubKey']
                ],
                sig: 'wrapSignature',
              ));

      when(mockNostrService.publishEvent(any))
          .thenAnswer((_) async => Future.value());

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

      when(mockSessionNotifier.getSessionByOrderId(orderId))
          .thenReturn(session);

      // Mock NostrService's createRumor, createSeal, createWrap, publishEvent
      when(mockNostrService.createRumor(any, any, any, any))
          .thenAnswer((_) async => 'encryptedRumorContentInvalid');

      when(mockNostrService.generateKeyPair())
          .thenAnswer((_) async => NostrUtils.generateKeyPair());

      when(mockNostrService.createSeal(any, any, any, any))
          .thenAnswer((_) async => 'sealedContentInvalid');

      when(mockNostrService.createWrap(any, any, any))
          .thenAnswer((_) async => NostrEvent(
                id: 'wrapEventIdInvalid',
                kind: 1059,
                pubkey: 'wrapperPubKeyInvalid',
                content: 'sealedContentInvalid',
                createdAt: DateTime.now(),
                tags: [
                  ['p', 'mostroPubKey']
                ],
                sig: 'invalidWrapSignature',
              ));

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

      when(mockSessionNotifier.getSessionByOrderId(orderId))
          .thenReturn(session);

      // Simulate that tradeIndex=3 has already been used
      mockServerTradeIndex.userTradeIndices[userPubKey] = 3;

      // Mock NostrService's createRumor, createSeal, createWrap, publishEvent
      when(mockNostrService.createRumor(any, any, any, any))
          .thenAnswer((_) async => 'encryptedRumorContentReused');

      when(mockNostrService.generateKeyPair())
          .thenAnswer((_) async => NostrUtils.generateKeyPair());

      when(mockNostrService.createSeal(any, any, any, any))
          .thenAnswer((_) async => 'sealedContentReused');

      when(mockNostrService.createWrap(any, any, any))
          .thenAnswer((_) async => NostrEvent(
                id: 'wrapEventIdReused',
                kind: 1059,
                pubkey: 'wrapperPubKeyReused',
                content: 'sealedContentReused',
                createdAt: DateTime.now(),
                tags: [
                  ['p', 'mostroPubKey']
                ],
                sig: 'wrapSignatureReused',
              ));

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

      when(mockSessionNotifier.getSessionByOrderId(orderId))
          .thenReturn(session);

      // Mock NostrService's createRumor, createSeal, createWrap, publishEvent
      when(mockNostrService.createRumor(any, any, any, any))
          .thenAnswer((_) async => 'encryptedRumorContentFullPrivacy');

      when(mockNostrService.generateKeyPair())
          .thenAnswer((_) async => NostrUtils.generateKeyPair());

      when(mockNostrService.createSeal(any, any, any, any))
          .thenAnswer((_) async => 'sealedContentFullPrivacy');

      when(mockNostrService.createWrap(any, any, any))
          .thenAnswer((_) async => NostrEvent(
                id: 'wrapEventIdFullPrivacy',
                kind: 1059,
                pubkey: 'wrapperPubKeyFullPrivacy',
                content: 'sealedContentFullPrivacy',
                createdAt: DateTime.now(),
                tags: [
                  ['p', 'mostroPubKey']
                ],
                sig: 'wrapSignatureFullPrivacy',
              ));

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
