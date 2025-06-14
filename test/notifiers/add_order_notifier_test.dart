import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';

import '../mocks.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AddOrderNotifier - Mockito tests', () {
    late ProviderContainer container;
    late MockMostroService mockMostroService;
    late MockOpenOrdersRepository mockOrdersRepository;
    late MockSharedPreferencesAsync mockSharedPreferencesAsync;

    const testUuid = "test_uuid";

    setUp(() {
      container = ProviderContainer();
      mockMostroService = MockMostroService();
      mockOrdersRepository = MockOpenOrdersRepository();
      mockSharedPreferencesAsync = MockSharedPreferencesAsync();
    });

    tearDown(() {
      container.dispose();
    });

    /// Helper that sets up the mock repository so that when `publishOrder` is
    /// called, it returns a Stream<MostroMessage> based on `confirmationJson`.
    void configureMockPublishOrder(Map<String, dynamic> confirmationJson) {
      //final confirmationMessage = MostroMessage.fromJson(confirmationJson);
      when(mockMostroService.submitOrder(any)).thenAnswer((invocation) async {
        // Return a stream that emits the confirmation message once.
        //return Stream.value(confirmationMessage);
      });
    }

    test('New Sell Order (Fixed)', () async {
      // This JSON simulates the confirmation message from Mostro for a new sell order.
      final confirmationJsonSell = {
        "order": {
          "version": 1,
          "id": "order_id_sell",
          "action": "new-order",
          "payload": {
            "order": {
              "id": "order_id_sell",
              "kind": "sell",
              "status": "pending",
              "amount": 0,
              "fiat_code": "VES",
              "min_amount": null,
              "max_amount": null,
              "fiat_amount": 100,
              "payment_method": "face to face",
              "premium": 1,
              "created_at": 0
            }
          }
        }
      };
      configureMockPublishOrder(confirmationJsonSell);

      // Override the repository provider with our mock.
      container = ProviderContainer(overrides: [
        mostroServiceProvider.overrideWithValue(mockMostroService),
        orderRepositoryProvider.overrideWithValue(mockOrdersRepository),
        sharedPreferencesProvider.overrideWithValue(mockSharedPreferencesAsync),
      ]);

      // Create a new sell (fixed) order.
      final newSellOrder = Order(
        kind: OrderType.sell,
        status: Status.pending,
        amount: 0,
        fiatCode: 'VES',
        fiatAmount: 100,
        paymentMethod: 'face to face',
        premium: 1,
      );

      final notifier =
          container.read(addOrderNotifierProvider(testUuid).notifier);

      // Submit the order
      await notifier.submitOrder(newSellOrder);

      // Retrieve the final state
      final state = container.read(addOrderNotifierProvider(testUuid));
      expect(state, isNotNull);

      final confirmedOrder = state.order;
      expect(confirmedOrder, isNotNull);
      expect(confirmedOrder!.kind, equals(OrderType.sell));
      expect(confirmedOrder.status.value, equals('pending'));
      expect(confirmedOrder.amount, equals(0));
      expect(confirmedOrder.fiatCode, equals('VES'));
      expect(confirmedOrder.fiatAmount, equals(100));
      expect(confirmedOrder.paymentMethod, equals('face to face'));
      expect(confirmedOrder.premium, equals(1));
      expect(confirmedOrder.createdAt, equals(0));

      // Optionally verify that publishOrder was called exactly once.
      verify(mockMostroService.publishOrder(any)).called(1);
    });

    test('New Sell Range Order', () async {
      final confirmationJsonSellRange = {
        "order": {
          "version": 1,
          "id": "order_id_sell_range",
          "action": "new-order",
          "payload": {
            "order": {
              "id": "order_id_sell_range",
              "kind": "sell",
              "status": "pending",
              "amount": 0,
              "fiat_code": "VES",
              "min_amount": 10,
              "max_amount": 20,
              "fiat_amount": 0,
              "payment_method": "face to face",
              "premium": 1,
              "created_at": 0
            }
          }
        }
      };
      configureMockPublishOrder(confirmationJsonSellRange);

      container = ProviderContainer(overrides: [
        mostroServiceProvider.overrideWithValue(mockMostroService),
        orderRepositoryProvider.overrideWithValue(mockOrdersRepository),
        sharedPreferencesProvider.overrideWithValue(mockSharedPreferencesAsync),
      ]);

      final newSellRangeOrder = Order(
        kind: OrderType.sell,
        status: Status.pending,
        amount: 0,
        fiatCode: 'VES',
        minAmount: 10,
        maxAmount: 20,
        fiatAmount: 0,
        paymentMethod: 'face to face',
        premium: 1,
      );

      final notifier =
          container.read(addOrderNotifierProvider(testUuid).notifier);
      await notifier.submitOrder(newSellRangeOrder);

      final state = container.read(orderNotifierProvider(testUuid));
      expect(state, isNotNull);

      final confirmedOrder = state.order;
      expect(confirmedOrder, isNotNull);
      expect(confirmedOrder!.kind, equals(OrderType.sell));
      expect(confirmedOrder.status.value, equals('pending'));
      expect(confirmedOrder.amount, equals(0));
      expect(confirmedOrder.minAmount, equals(10));
      expect(confirmedOrder.maxAmount, equals(20));
      expect(confirmedOrder.fiatAmount, equals(0));
      expect(confirmedOrder.paymentMethod, equals('face to face'));
      expect(confirmedOrder.premium, equals(1));

      verify(mockMostroService.publishOrder(any)).called(1);
    });

    test('New Buy Order', () async {
      final confirmationJsonBuy = {
        "order": {
          "version": 1,
          "id": "order_id_buy",
          "action": "new-order",
          "payload": {
            "order": {
              "id": "order_id_buy",
              "kind": "buy",
              "status": "pending",
              "amount": 0,
              "fiat_code": "VES",
              "fiat_amount": 100,
              "payment_method": "face to face",
              "premium": 1,
              "master_buyer_pubkey": null,
              "master_seller_pubkey": null,
              "buyer_invoice": null,
              "created_at": 0
            }
          }
        }
      };
      configureMockPublishOrder(confirmationJsonBuy);

      container = ProviderContainer(overrides: [
        mostroServiceProvider.overrideWithValue(mockMostroService),
        orderRepositoryProvider.overrideWithValue(mockOrdersRepository),
        sharedPreferencesProvider.overrideWithValue(mockSharedPreferencesAsync),
      ]);

      final newBuyOrder = Order(
        kind: OrderType.buy,
        status: Status.pending,
        amount: 0,
        fiatCode: 'VES',
        fiatAmount: 100,
        paymentMethod: 'face to face',
        premium: 1,
      );

      final notifier =
          container.read(addOrderNotifierProvider(testUuid).notifier);
      await notifier.submitOrder(newBuyOrder);

      final state = container.read(addOrderNotifierProvider(testUuid));
      expect(state, isNotNull);

      final confirmedOrder = state.order;
      expect(confirmedOrder, isNotNull);
      expect(confirmedOrder!.kind, equals(OrderType.buy));
      expect(confirmedOrder.status.value, equals('pending'));
      expect(confirmedOrder.fiatCode, equals('VES'));
      expect(confirmedOrder.fiatAmount, equals(100));
      expect(confirmedOrder.paymentMethod, equals('face to face'));
      expect(confirmedOrder.premium, equals(1));
      expect(confirmedOrder.buyerInvoice, isNull);

      verify(mockMostroService.publishOrder(any)).called(1);
    });

    test('New Buy Order with Lightning Address', () async {
      final confirmationJsonBuyInvoice = {
        "order": {
          "version": 1,
          "id": "order_id_buy_invoice",
          "action": "new-order",
          "payload": {
            "order": {
              "id": "order_id_buy_invoice",
              "kind": "buy",
              "status": "pending",
              "amount": 0,
              "fiat_code": "VES",
              "fiat_amount": 100,
              "payment_method": "face to face",
              "premium": 1,
              "master_buyer_pubkey": null,
              "master_seller_pubkey": null,
              "buyer_invoice": "mostro_p2p@ln.tips",
              "created_at": 0
            }
          }
        }
      };
      configureMockPublishOrder(confirmationJsonBuyInvoice);

      container = ProviderContainer(overrides: [
        mostroServiceProvider.overrideWithValue(mockMostroService),
        orderRepositoryProvider.overrideWithValue(mockOrdersRepository),
        sharedPreferencesProvider.overrideWithValue(mockSharedPreferencesAsync),
      ]);

      final newBuyOrderWithInvoice = Order(
        kind: OrderType.buy,
        status: Status.pending,
        amount: 0,
        fiatCode: 'VES',
        fiatAmount: 100,
        paymentMethod: 'face to face',
        premium: 1,
        buyerInvoice: 'mostro_p2p@ln.tips',
      );

      final notifier =
          container.read(addOrderNotifierProvider(testUuid).notifier);
      await notifier.submitOrder(newBuyOrderWithInvoice);

      final state = container.read(orderNotifierProvider(testUuid));
      expect(state, isNotNull);

      final confirmedOrder = state.order;
      expect(confirmedOrder, isNotNull);
      expect(confirmedOrder!.kind, equals(OrderType.buy));
      expect(confirmedOrder.status.value, equals('pending'));
      expect(confirmedOrder.fiatAmount, equals(100));
      expect(confirmedOrder.paymentMethod, equals('face to face'));
      expect(confirmedOrder.premium, equals(1));
      expect(confirmedOrder.buyerInvoice, equals('mostro_p2p@ln.tips'));

      verify(mockMostroService.publishOrder(any)).called(1);
    });
  });
}
