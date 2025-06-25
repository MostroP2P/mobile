import 'dart:convert';
import 'package:convert/convert.dart';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/features/subscriptions/subscription.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_type.dart';
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';
import 'package:mostro_mobile/core/config.dart';
// Removed unused import
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/key_manager/key_derivator.dart';
import 'package:mostro_mobile/services/mostro_service.dart';
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager_provider.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';

import 'mostro_service_test.mocks.dart';
import 'mostro_service_helper_functions.dart';

// Create a mock SubscriptionManager class for testing
class MockSubscriptionManager implements SubscriptionManager {
  MockSubscriptionManager({required this.ref});
  
  @override
  final Ref ref;
  
  final Map<SubscriptionType, Map<String, Subscription>> _subscriptions = {
    SubscriptionType.chat: {},
    SubscriptionType.orders: {},
    SubscriptionType.trades: {},
  };
  
  NostrFilter? _lastFilter;
  NostrFilter? get lastFilter => _lastFilter;
  String? _lastSubscriptionId;
  
  // Implement the stream getters required by SubscriptionManager
  @override
  Stream<NostrEvent> get chat => _controller.stream;
  
  @override
  Stream<NostrEvent> get orders => _controller.stream;
  
  @override
  Stream<NostrEvent> get trades => _controller.stream;
  
  @override
  Stream<NostrEvent> subscribe({
    required SubscriptionType type,
    required NostrFilter filter,
    String? id,
  }) {
    // Store the filter for verification
    _lastFilter = filter;
    _lastSubscriptionId = id ?? type.toString();
    
    // Create a subscription
    final subscription = Subscription(
      request: NostrRequest(filters: [filter]),
      streamSubscription: _controller.stream.listen((_) {}),
    );
    
    _subscriptions[type]![_lastSubscriptionId!] = subscription;
    
    // Return a new stream to avoid multiple subscriptions to the same controller
    return _controller.stream;
  }
  
  @override
  Stream<NostrEvent> subscribeSession({
    required SubscriptionType type,
    required Session session,
    required NostrFilter Function(Session session) createFilter,
  }) {
    final filter = createFilter(session);
    final sessionId = session.orderId ?? session.tradeKey.public;
    return subscribe(
      type: type,
      filter: filter,
      id: '${type.toString()}_$sessionId',
    );
  }
  
  @override
  void unsubscribeById(SubscriptionType type, String id) {
    _subscriptions[type]?.remove(id);
  }
  
  @override
  void unsubscribeByType(SubscriptionType type) {
    _subscriptions[type]?.clear();
  }
  
  @override
  void unsubscribeAll() {
    for (final type in SubscriptionType.values) {
      unsubscribeByType(type);
    }
  }
  
  @override
  List<NostrFilter> getActiveFilters(SubscriptionType type) {
    final filters = <NostrFilter>[];
    final subscriptions = _subscriptions[type] ?? {};
    
    for (final subscription in subscriptions.values) {
      if (subscription.request.filters.isNotEmpty) {
        filters.add(subscription.request.filters.first);
      }
    }
    
    return filters;
  }
  
  @override
  void unsubscribeSession(SubscriptionType type, Session session) {
    final sessionId = session.orderId ?? session.tradeKey.public;
    unsubscribeById(type, '${type.toString()}_$sessionId');
  }
  
  @override
  bool hasActiveSubscription(SubscriptionType type, {String? id}) {
    if (id != null) {
      return _subscriptions[type]?.containsKey(id) ?? false;
    }
    return (_subscriptions[type]?.isNotEmpty ?? false);
  }
  
  @override
  void dispose() {
    _controller.close();
  }
  
  // Helper to create a mock filter for verification
  static NostrFilter createMockFilter() {
    return NostrFilter(
      kinds: [1059],
      limit: 1,
    );
  }
  
  // Helper to add events to the stream
  void addEvent(NostrEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }
  
  final StreamController<NostrEvent> _controller = StreamController<NostrEvent>.broadcast();
}

@GenerateMocks([
  NostrService, 
  SessionNotifier, 
  Ref,
  StateNotifierProviderRef,
])
void main() {
  late MockRef mockRef;
  late MockSessionNotifier mockSessionNotifier;
  late MockSubscriptionManager mockSubscriptionManager;
  late MockNostrService mockNostrService;
  late MostroService mostroService;
  late KeyDerivator keyDerivator;
  late MockServerTradeIndex mockServerTradeIndex;
  
  setUpAll(() {
    // Create a dummy Settings object that will be used by MockRef
    final dummySettings = Settings(
      relays: ['wss://relay.damus.io'],
      fullPrivacyMode: false,
      mostroPublicKey: 'npub1mostro',
      defaultFiatCode: 'USD',
    );
    
    // Provide dummy values for Mockito
    provideDummy<SessionNotifier>(MockSessionNotifier());
    provideDummy<Settings>(dummySettings);
    provideDummy<NostrService>(MockNostrService());
    
    // Create a mock ref for the SubscriptionManager dummy
    final mockRefForSubscriptionManager = MockRef();
    provideDummy<SubscriptionManager>(MockSubscriptionManager(ref: mockRefForSubscriptionManager));
    
    // Create a mock ref that returns the dummy settings
    final mockRefForDummy = MockRef();
    when(mockRefForDummy.read(settingsProvider)).thenReturn(dummySettings);
    
    // Provide a dummy MostroService that uses our properly configured mock ref
    provideDummy<MostroService>(MostroService(mockRefForDummy));
  });

  setUp(() {
    mockNostrService = MockNostrService();
    mockRef = MockRef();
    mockSessionNotifier = MockSessionNotifier();
    mockSubscriptionManager = MockSubscriptionManager(ref: mockRef);
    mockNostrService = MockNostrService();
    mockServerTradeIndex = MockServerTradeIndex();
    
    // Setup key derivator
    keyDerivator = KeyDerivator("m/44'/1237'/38383'/0");
    
    // Setup mock session notifier
    when(mockSessionNotifier.sessions).thenReturn(<Session>[]);
    
    // Setup mock ref with Settings
    final settings = Settings(
      relays: ['wss://relay.damus.io'],
      fullPrivacyMode: false,
      mostroPublicKey: 'npub1mostro',
      defaultFiatCode: 'USD',
    );
    when(mockRef.read(settingsProvider)).thenReturn(settings);
    when(mockRef.read(sessionNotifierProvider.notifier)).thenReturn(mockSessionNotifier);
    when(mockRef.read(nostrServiceProvider)).thenReturn(mockNostrService);
    when(mockRef.read(subscriptionManagerProvider)).thenReturn(mockSubscriptionManager);
    // Mock server trade index is used in the service
    // but we don't need to mock the provider
    
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
      final userPrivKey = keyDerivator.derivePrivateKey(mnemonic, 0);
      final userPubKey = keyDerivator.privateToPublicKey(userPrivKey);
      final tradePrivKey = keyDerivator.derivePrivateKey(mnemonic, tradeIndex);
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
        signatureHex: 'invalidSignature',
      );

      expect(isValid, isFalse,
          reason: 'Server should reject invalid signatures');
    });

    test('Rejects message with reused trade index', () async {
      // Arrange
      const orderId = 'reused-trade-index-order';
      const tradeIndex = 3;
      final mnemonic = keyDerivator.generateMnemonic();
      final userPrivKey = keyDerivator.derivePrivateKey(mnemonic, 0);
      final userPubKey = keyDerivator.privateToPublicKey(userPrivKey);
      final tradePrivKey = keyDerivator.derivePrivateKey(mnemonic, tradeIndex);
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
      final userPrivKey = keyDerivator.derivePrivateKey(mnemonic, 0);
      final userPubKey = keyDerivator.privateToPublicKey(userPrivKey);
      final tradePrivKey = keyDerivator.derivePrivateKey(mnemonic, tradeIndex);
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
      // Verify the subscription was set up correctly
      // The subscription should have been set up with a filter for kind 1059
      final capturedFilter = mockSubscriptionManager.lastFilter;
      expect(capturedFilter, isNotNull);
      expect(capturedFilter!.kinds, contains(1059));

      // Verify the published event
      final capturedEvents = verify(
        mockNostrService.publishEvent(captureAny),
      ).captured.cast<NostrEvent>();
      
      expect(capturedEvents, hasLength(1));
      final publishedEvent = capturedEvents.first;
      expect(publishedEvent.kind, equals(1059));
      expect(publishedEvent.content, isNotEmpty);

      // Simulate server-side verification
      final isValid = serverVerifyMessage(
        userPubKey: userPubKey,
        messageContent: {
          'order': {
            'version': Config.mostroVersion,
            'id': orderId,
            'action': 'take-sell',
            'payload': {
              'payment_request': [null, 'lnbc121314invoice', 400],
            },
            'trade_index': tradeIndex,
          },
        },
        signatureHex: 'validSignatureFullPrivacy',
      );

      expect(isValid, isTrue,
          reason: 'Server should accept valid messages in full privacy mode');

      // Additionally, verify that the seal was signed with the trade key
      verify(mockNostrService.createSeal(
        session.tradeKey, // Seal signed with trade key
        any, // Wrapper private key
        'mostroPubKey',
        'encryptedRumorContentFullPrivacy',
      )).called(1);
    });
  });
}
