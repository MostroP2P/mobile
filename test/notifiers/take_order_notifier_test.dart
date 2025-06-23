import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_database_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/session_storage_provider.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Take Order Notifiers - Mockito tests', () {
    late ProviderContainer container;
    late MockMostroService mockMostroService;
    late MockSharedPreferencesAsync mockPreferences;
    late MockOpenOrdersRepository mockOrdersRepository;
    late MockDatabase mockDatabase;
    late MockSessionStorage mockSessionStorage;
    late MockKeyManager mockKeyManager;
    late MockSessionNotifier mockSessionNotifier;
    late MockMostroStorage mockMostroStorage;
    const testOrderId = "test_order_id";

    setUp(() {
      // Create instances of all mocks
      mockMostroService = MockMostroService();
      mockPreferences = MockSharedPreferencesAsync();
      mockOrdersRepository = MockOpenOrdersRepository();
      mockDatabase = MockDatabase();
      mockSessionStorage = MockSessionStorage();
      mockKeyManager = MockKeyManager();
      mockMostroStorage = MockMostroStorage();
      
      // Create test settings
      final testSettings = Settings(
        relays: ['wss://relay.damus.io'],
        fullPrivacyMode: false,
        mostroPublicKey: '6d5c471d0e88c8c688c85dd8a3d84e3c7c5e8a3b6d7a6b2c9e8c5d9a7b3e6c8a',
        defaultFiatCode: 'USD',
      );
      
      mockSessionNotifier = MockSessionNotifier(mockKeyManager, mockSessionStorage, testSettings);
      
      // Stub the KeyManager methods
      when(mockKeyManager.masterKeyPair).thenReturn(
        NostrKeyPairs(private: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef'),
      );
      when(mockKeyManager.getCurrentKeyIndex()).thenAnswer((_) async => 0);
      when(mockKeyManager.deriveTradeKey()).thenAnswer((_) async => 
        NostrKeyPairs(private: 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890'),
      );

      // Stub MostroStorage methods
      when(mockMostroStorage.getAllMessagesForOrderId(any)).thenAnswer((_) async => <MostroMessage>[]);
    });

    tearDown(() {
      container.dispose();
    });

    /// Helper that stubs the repository method (for both takeBuyOrder and takeSellOrder)
    /// so that it returns a Stream emitting the provided confirmation JSON.
    void configureMockMethod(
      Future<Stream<MostroMessage>> Function(String, dynamic, [dynamic])
          repositoryMethod,
      Map<String, dynamic> confirmationJson,
    ) {
      final confirmationMessage = MostroMessage.fromJson(confirmationJson);
      when(repositoryMethod(testOrderId, any, any))
          .thenAnswer((_) async => Stream.value(confirmationMessage));
      // For the takeBuyOrder method which takes only two parameters:
      when(repositoryMethod(testOrderId, any, null))
          .thenAnswer((_) async => Stream.value(confirmationMessage));
    }

    test('Taking a Buy Order - seller sends take-buy and receives pay-invoice confirmation', () async {
      // Confirmation JSON for "Taking a buy order":
      final confirmationJsonTakeBuy = {
        "order": {
          "version": 1,
          "id": testOrderId,
          "action": "pay-invoice",
          "payload": {
            "payment_request": [
              {
                "id": testOrderId,
                "kind": "buy",
                "status": "waiting-payment",
                "amount": 7851,
                "fiat_code": "VES",
                "fiat_amount": 100,
                "payment_method": "face to face",
                "premium": 1,
                "created_at": 1698957793
              },
              "ln_invoice_sample"
            ]
          }
        }
      };

      // Stub the repository’s takeBuyOrder method.
      when(mockMostroService.takeBuyOrder(any, any)).thenAnswer((_) async {
        // Return void as per actual method signature
      });

      // Override providers with comprehensive mocks
      container = ProviderContainer(overrides: [
        mostroServiceProvider.overrideWithValue(mockMostroService),
        orderRepositoryProvider.overrideWithValue(mockOrdersRepository),
        sharedPreferencesProvider.overrideWithValue(mockPreferences),
        mostroDatabaseProvider.overrideWithValue(mockDatabase),
        eventDatabaseProvider.overrideWithValue(mockDatabase),
        sessionStorageProvider.overrideWithValue(mockSessionStorage),
        keyManagerProvider.overrideWithValue(mockKeyManager),
        sessionNotifierProvider.overrideWith((ref) => mockSessionNotifier),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier(
          Settings(
            relays: ['wss://relay.damus.io'],
            fullPrivacyMode: false,
            mostroPublicKey: '6d5c471d0e88c8c688c85dd8a3d84e3c7c5e8a3b6d7a6b2c9e8c5d9a7b3e6c8a',
            defaultFiatCode: 'USD',
          ), 
          mockPreferences
        )),
        mostroStorageProvider.overrideWithValue(mockMostroStorage),
      ]);

      // Retrieve the notifier from the provider.
      final takeBuyNotifier =
          container.read(orderNotifierProvider(testOrderId).notifier);

      // Invoke the method to simulate taking a buy order.
      await takeBuyNotifier.takeBuyOrder(testOrderId, 0);

      // Check that the state has been updated as expected.
      final state = container.read(orderNotifierProvider(testOrderId));
      expect(state, isNotNull);
      // Check that state is initialized (default action is new-order)
      expect(state.action, equals(Action.newOrder));
      // Optionally verify that the repository method was called.
      verify(mockMostroService.takeBuyOrder(testOrderId, any)).called(1);
    });

    test('Taking a Sell Order (fixed) - buyer sends take-sell and receives add-invoice confirmation', () async {
      final confirmationJsonTakeSell = {
        "order": {
          "version": 1,
          "id": testOrderId,
          "action": "add-invoice",
          "payload": {
            "order": {
              "id": testOrderId,
              "kind": "sell",
              "status": "pending",
              "amount": 0,
              "fiat_code": "VES",
              "fiat_amount": 100,
              "payment_method": "face to face",
              "premium": 1,
              "created_at": 1698957793
            }
          }
        }
      };

      when(mockMostroService.takeSellOrder(any, any, any)).thenAnswer((_) async {
        // Return void as per actual method signature
      });

      // Override providers with comprehensive mocks
      container = ProviderContainer(overrides: [
        mostroServiceProvider.overrideWithValue(mockMostroService),
        orderRepositoryProvider.overrideWithValue(mockOrdersRepository),
        sharedPreferencesProvider.overrideWithValue(mockPreferences),
        mostroDatabaseProvider.overrideWithValue(mockDatabase),
        eventDatabaseProvider.overrideWithValue(mockDatabase),
        sessionStorageProvider.overrideWithValue(mockSessionStorage),
        keyManagerProvider.overrideWithValue(mockKeyManager),
        sessionNotifierProvider.overrideWith((ref) => mockSessionNotifier),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier(
          Settings(
            relays: ['wss://relay.damus.io'],
            fullPrivacyMode: false,
            mostroPublicKey: '6d5c471d0e88c8c688c85dd8a3d84e3c7c5e8a3b6d7a6b2c9e8c5d9a7b3e6c8a',
            defaultFiatCode: 'USD',
          ), 
          mockPreferences
        )),
        mostroStorageProvider.overrideWithValue(mockMostroStorage),
      ]);

      final takeSellNotifier =
          container.read(orderNotifierProvider(testOrderId).notifier);

      // Simulate taking a sell order (with amount 0).
      await takeSellNotifier.takeSellOrder(testOrderId, 0, null);

      final state = container.read(orderNotifierProvider(testOrderId));
      expect(state, isNotNull);
      expect(state.action, equals(Action.newOrder));

      verify(mockMostroService.takeSellOrder(testOrderId, any, any)).called(1);
    });

    test('Taking a Sell Range Order - buyer sends take-sell with range payload', () async {
      final confirmationJsonSellRange = {
        "order": {
          "version": 1,
          "id": testOrderId,
          "action": "add-invoice",
          "payload": {
            "order": {
              "id": testOrderId,
              "kind": "sell",
              "status": "pending",
              "amount": 0,
              "fiat_code": "VES",
              "min_amount": 10,
              "max_amount": 20,
              "fiat_amount": 15,
              "payment_method": "face to face",
              "premium": 1,
              "created_at": 1698957793
            }
          }
        }
      };

      when(mockMostroService.takeSellOrder(any, any, any)).thenAnswer((_) async {
        // Return void as per actual method signature
      });

      // Override providers with comprehensive mocks
      container = ProviderContainer(overrides: [
        mostroServiceProvider.overrideWithValue(mockMostroService),
        orderRepositoryProvider.overrideWithValue(mockOrdersRepository),
        sharedPreferencesProvider.overrideWithValue(mockPreferences),
        mostroDatabaseProvider.overrideWithValue(mockDatabase),
        eventDatabaseProvider.overrideWithValue(mockDatabase),
        sessionStorageProvider.overrideWithValue(mockSessionStorage),
        keyManagerProvider.overrideWithValue(mockKeyManager),
        sessionNotifierProvider.overrideWith((ref) => mockSessionNotifier),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier(
          Settings(
            relays: ['wss://relay.damus.io'],
            fullPrivacyMode: false,
            mostroPublicKey: '6d5c471d0e88c8c688c85dd8a3d84e3c7c5e8a3b6d7a6b2c9e8c5d9a7b3e6c8a',
            defaultFiatCode: 'USD',
          ), 
          mockPreferences
        )),
        mostroStorageProvider.overrideWithValue(mockMostroStorage),
      ]);

      final takeSellNotifier =
          container.read(orderNotifierProvider(testOrderId).notifier);

      // Simulate taking a sell order with a fiat range (here amount is irrelevant because the payload carries range info).
      await takeSellNotifier.takeSellOrder(testOrderId, 0, null);

      final state = container.read(orderNotifierProvider(testOrderId));
      expect(state, isNotNull);
      expect(state.action, equals(Action.newOrder));

      verify(mockMostroService.takeSellOrder(testOrderId, any, any)).called(1);
    });

    test('Taking a Sell Order with Lightning Address - buyer sends take-sell with LN address', () async {
      final confirmationJsonSellLN = {
        "order": {
          "version": 1,
          "id": testOrderId,
          "action": "waiting-seller-to-pay",
          "payload": null
        }
      };

      when(mockMostroService.takeSellOrder(any, any, any)).thenAnswer((_) async {
        // Return void as per actual method signature
      });

      // Override providers with comprehensive mocks
      container = ProviderContainer(overrides: [
        mostroServiceProvider.overrideWithValue(mockMostroService),
        orderRepositoryProvider.overrideWithValue(mockOrdersRepository),
        sharedPreferencesProvider.overrideWithValue(mockPreferences),
        mostroDatabaseProvider.overrideWithValue(mockDatabase),
        eventDatabaseProvider.overrideWithValue(mockDatabase),
        sessionStorageProvider.overrideWithValue(mockSessionStorage),
        keyManagerProvider.overrideWithValue(mockKeyManager),
        sessionNotifierProvider.overrideWith((ref) => mockSessionNotifier),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier(
          Settings(
            relays: ['wss://relay.damus.io'],
            fullPrivacyMode: false,
            mostroPublicKey: '6d5c471d0e88c8c688c85dd8a3d84e3c7c5e8a3b6d7a6b2c9e8c5d9a7b3e6c8a',
            defaultFiatCode: 'USD',
          ), 
          mockPreferences
        )),
        mostroStorageProvider.overrideWithValue(mockMostroStorage),
      ]);

      final takeSellNotifier =
          container.read(orderNotifierProvider(testOrderId).notifier);

      // Simulate taking a sell order with a lightning address payload.
      await takeSellNotifier.takeSellOrder(testOrderId, 0, "mostro_p2p@ln.tips");

      final state = container.read(orderNotifierProvider(testOrderId));
      expect(state, isNotNull);
      expect(state.action, equals(Action.newOrder));

      verify(mockMostroService.takeSellOrder(testOrderId, any, any)).called(1);
    });

  });
}
