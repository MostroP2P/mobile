import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';

import '../mocks.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Take Order Notifiers - Mockito tests', () {
    late ProviderContainer container;
    late MockMostroService mockMostroService;
    const testOrderId = "test_order_id";

    setUp(() {
      // Create a new instance of the mock repository.
      mockMostroService = MockMostroService();

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
        final msg = MostroMessage.fromJson(confirmationJsonTakeBuy);
        return Stream.value(msg);
      });

      // Override the repository provider with our mock.
      container = ProviderContainer(overrides: [
        mostroServiceProvider.overrideWithValue(mockMostroService),
      ]);

      // Retrieve the notifier from the provider.
      final takeBuyNotifier =
          container.read(orderNotifierProvider(testOrderId).notifier);

      // Invoke the method to simulate taking a buy order.
      await takeBuyNotifier.takeBuyOrder(testOrderId, 0);

      // Check that the state has been updated as expected.
      final state = container.read(orderNotifierProvider(testOrderId));
      expect(state, isNotNull);
      // We expect the confirmation action to be "pay-invoice".
      expect(state.action, equals(Action.payInvoice));
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
        final msg = MostroMessage.fromJson(confirmationJsonTakeSell);
        return Stream.value(msg);
      });

      // Override the repository provider with our mock.
      container = ProviderContainer(overrides: [
        mostroServiceProvider.overrideWithValue(mockMostroService),
      ]);

      final takeSellNotifier =
          container.read(orderNotifierProvider(testOrderId).notifier);

      // Simulate taking a sell order (with amount 0).
      await takeSellNotifier.takeSellOrder(testOrderId, 0, null);

      final state = container.read(orderNotifierProvider(testOrderId));
      expect(state, isNotNull);
      expect(state.action, equals(Action.addInvoice));
      final orderPayload = state.getPayload<Order>();
      expect(orderPayload, isNotNull);
      expect(orderPayload!.amount, equals(0));
      expect(orderPayload.fiatCode, equals('VES'));
      expect(orderPayload.fiatAmount, equals(100));
      expect(orderPayload.paymentMethod, equals('face to face'));
      expect(orderPayload.premium, equals(1));

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
        final msg = MostroMessage.fromJson(confirmationJsonSellRange);
        return Stream.value(msg);
      });

      // Override the repository provider with our mock.
      container = ProviderContainer(overrides: [
        mostroServiceProvider.overrideWithValue(mockMostroService),
      ]);

      final takeSellNotifier =
          container.read(orderNotifierProvider(testOrderId).notifier);

      // Simulate taking a sell order with a fiat range (here amount is irrelevant because the payload carries range info).
      await takeSellNotifier.takeSellOrder(testOrderId, 0, null);

      final state = container.read(orderNotifierProvider(testOrderId));
      expect(state, isNotNull);
      expect(state.action, equals(Action.addInvoice));
      final orderPayload = state.getPayload<Order>();
      expect(orderPayload, isNotNull);
      expect(orderPayload!.minAmount, equals(10));
      expect(orderPayload.maxAmount, equals(20));
      expect(orderPayload.fiatAmount, equals(15));

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
        final msg = MostroMessage.fromJson(confirmationJsonSellLN);
        return Stream.value(msg);
      });

      // Override the repository provider with our mock.
      container = ProviderContainer(overrides: [
        mostroServiceProvider.overrideWithValue(mockMostroService),
      ]);

      final takeSellNotifier =
          container.read(orderNotifierProvider(testOrderId).notifier);

      // Simulate taking a sell order with a lightning address payload.
      await takeSellNotifier.takeSellOrder(testOrderId, 0, "mostro_p2p@ln.tips");

      final state = container.read(orderNotifierProvider(testOrderId));
      expect(state, isNotNull);
      expect(state.action, equals(Action.waitingSellerToPay));

      verify(mockMostroService.takeSellOrder(testOrderId, any, any)).called(1);
    });

  });
}
