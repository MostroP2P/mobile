import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as mostro;
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';
import 'package:mostro_mobile/features/order/notifiers/order_notifier.dart';
import 'package:mostro_mobile/features/order/providers/market_check_provider.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/order/providers/settlement_anchor_provider.dart';
import 'package:mostro_mobile/features/order/screens/add_lightning_invoice_screen.dart';
import 'package:mostro_mobile/features/wallet/providers/nwc_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/widgets/add_lightning_invoice_widget.dart';
import 'package:mostro_mobile/shared/utils/market_quote.dart';

const _orderId = 'order-1';

/// Holds a fixed [OrderState] without any of the notifier's real machinery.
class _StubOrderNotifier extends StateNotifier<OrderState>
    implements OrderNotifier {
  _StubOrderNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Reports a disconnected wallet, so the screen takes the manual flow.
class _StubNwcNotifier extends StateNotifier<NwcState> implements NwcNotifier {
  _StubNwcNotifier() : super(const NwcState());

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// The node's `add-invoice` message, asking the buyer for [requestedSats].
MostroMessage<Order>? _request(int? requestedSats) {
  if (requestedSats == null) return null;

  return MostroMessage<Order>(
    action: mostro.Action.addInvoice,
    id: _orderId,
    payload: Order(
      id: _orderId,
      kind: OrderType.sell,
      status: Status.waitingBuyerInvoice,
      amount: requestedSats,
      fiatCode: 'USD',
      fiatAmount: 100,
      paymentMethod: 'bank',
      premium: 0,
    ),
  );
}

Future<void> pumpAddScreen(
  WidgetTester tester, {
  required int? requestedSats,
  int? anchoredSats,
  MarketCheck? market,
}) async {
  final state = OrderState(
    status: Status.waitingBuyerInvoice,
    action: mostro.Action.addInvoice,
    order: _request(requestedSats)?.getPayload<Order>(),
  );

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const AddLightningInvoiceScreen(orderId: _orderId),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mostroOrderStreamProvider
            .overrideWith((ref, id) => Stream.value(_request(requestedSats))),
        orderNotifierProvider
            .overrideWith((ref, id) => _StubOrderNotifier(state)),
        nwcProvider.overrideWith((ref) => _StubNwcNotifier()),
        sessionProvider.overrideWith((ref, id) => null),
        anchoredBuyerAmountProvider.overrideWith((ref, id) => anchoredSats),
        marketCheckProvider.overrideWith((ref, id) => market),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

S _s(WidgetTester tester) => S.of(tester.element(find.byType(Scaffold)))!;

void main() {
  group('AddLightningInvoiceScreen gating', () {
    testWidgets('refuses a request that disagrees with the signed terms',
        (tester) async {
      // The sibling finding's scenario: the trade is for 99,700 after fees and
      // the node asks the buyer to invoice for 90,000.
      await pumpAddScreen(tester, requestedSats: 90000, anchoredSats: 99700);

      expect(find.text(_s(tester).invoiceRequestMismatchTitle), findsOneWidget);
      expect(find.byType(AddLightningInvoiceWidget), findsNothing);
    });

    testWidgets('accepts a request that matches the signed terms',
        (tester) async {
      await pumpAddScreen(tester, requestedSats: 99700, anchoredSats: 99700);

      expect(find.text(_s(tester).invoiceRequestMismatchTitle), findsNothing);
      expect(find.byType(AddLightningInvoiceWidget), findsOneWidget);
    });

    testWidgets('a pending request is not a mismatch', (tester) async {
      // No message has arrived yet, so there is no requested figure. Reading
      // that absence as a disagreement would strand the screen on a refusal
      // whose only action is Cancel.
      await pumpAddScreen(tester, requestedSats: null, anchoredSats: 99700);

      expect(find.text(_s(tester).invoiceRequestMismatchTitle), findsNothing);
    });

    testWidgets('cautions when the signed terms could not be derived',
        (tester) async {
      await pumpAddScreen(tester, requestedSats: 99700, anchoredSats: null);

      expect(find.text(_s(tester).invoiceTermsUnverifiedTitle), findsOneWidget);
      expect(find.text(_s(tester).invoiceRequestMismatchTitle), findsNothing);
    });

    testWidgets('says nothing extra when the terms were derived',
        (tester) async {
      await pumpAddScreen(tester, requestedSats: 99700, anchoredSats: 99700);

      expect(find.text(_s(tester).invoiceTermsUnverifiedTitle), findsNothing);
      expect(find.text(_s(tester).invoiceOffMarketTitle), findsNothing);
    });

    testWidgets('cautions when the order settles off the market rate',
        (tester) async {
      await pumpAddScreen(
        tester,
        requestedSats: 99700,
        anchoredSats: 99700,
        market: const MarketCheck(
          quotedSats: 200000,
          settledSats: 100000,
          deviation: 0.5,
        ),
      );

      expect(find.text(_s(tester).invoiceOffMarketTitle), findsOneWidget);
    });

    testWidgets('stays quiet when the settlement is on the market rate',
        (tester) async {
      await pumpAddScreen(
        tester,
        requestedSats: 99700,
        anchoredSats: 99700,
        market: const MarketCheck(
          quotedSats: 100100,
          settledSats: 100000,
          deviation: 0.001,
        ),
      );

      expect(find.text(_s(tester).invoiceOffMarketTitle), findsNothing);
    });
  });
}
