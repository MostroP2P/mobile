import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';
import 'package:mostro_mobile/features/order/notifiers/order_notifier.dart';
import 'package:mostro_mobile/features/order/providers/market_check_provider.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/order/providers/settlement_anchor_provider.dart';
import 'package:mostro_mobile/features/order/screens/payout_invoice_screen.dart';
import 'package:mostro_mobile/features/wallet/providers/nwc_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/utils/market_quote.dart';
import 'package:mostro_mobile/shared/widgets/add_lightning_invoice_widget.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as mostro;

const _orderId = 'order-1';

/// Holds a fixed [OrderState] without the notifier's real machinery.
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

Order _order(int sats) => Order(
      id: _orderId,
      kind: OrderType.buy,
      status: Status.settledHoldInvoice,
      amount: sats,
      fiatCode: 'USD',
      fiatAmount: 100,
      paymentMethod: 'cash',
      premium: 0,
    );

Future<void> pumpPayoutScreen(
  WidgetTester tester, {
  required int payoutSats,
  int? anchoredSats,
  MarketCheckResult marketResult = MarketCheckResult.notApplicable,
}) async {
  final order = _order(payoutSats);
  final state = OrderState(
    status: Status.settledHoldInvoice,
    action: mostro.Action.addInvoice,
    order: order,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        orderNotifierProvider
            .overrideWith((ref, id) => _StubOrderNotifier(state)),
        nwcProvider.overrideWith((ref) => _StubNwcNotifier()),
        anchoredBuyerAmountProvider.overrideWith((ref, id) => anchoredSats),
        marketCheckProvider.overrideWith((ref, id) => marketResult),
      ],
      child: MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: PayoutInvoiceScreen(orderId: _orderId, order: order),
      ),
    ),
  );
  await tester.pump();
}

S _s(WidgetTester tester) =>
    S.of(tester.element(find.byType(PayoutInvoiceScreen)))!;

void main() {
  group('PayoutInvoiceScreen settlement checks', () {
    testWidgets('says nothing when the payout matches the signed terms',
        (tester) async {
      await pumpPayoutScreen(tester, payoutSats: 99700, anchoredSats: 99700);

      final s = _s(tester);
      expect(find.text(s.payoutAmountMismatchTitle), findsNothing);
      expect(find.text(s.invoiceTermsUnverifiedTitle), findsNothing);
      expect(find.byType(AddLightningInvoiceWidget), findsOneWidget);
    });

    testWidgets('names a payout that disagrees with the signed terms',
        (tester) async {
      await pumpPayoutScreen(tester, payoutSats: 90000, anchoredSats: 99700);

      expect(find.text(_s(tester).payoutAmountMismatchTitle), findsOneWidget);
    });

    testWidgets('still lets the user collect when the amounts disagree',
        (tester) async {
      // The hold invoice is already settled and there is nothing to cancel.
      // A refusal here would leave the user unable to collect at all, which
      // is worse than collecting an amount they were shown to be wrong.
      await pumpPayoutScreen(tester, payoutSats: 90000, anchoredSats: 99700);

      expect(find.byType(AddLightningInvoiceWidget), findsOneWidget);
    });

    testWidgets('cautions when the signed terms could not be derived',
        (tester) async {
      await pumpPayoutScreen(tester, payoutSats: 99700, anchoredSats: null);

      final s = _s(tester);
      expect(find.text(s.invoiceTermsUnverifiedTitle), findsOneWidget);
      expect(find.byType(AddLightningInvoiceWidget), findsOneWidget);
    });

    testWidgets('names an off-market payout without stopping it',
        (tester) async {
      await pumpPayoutScreen(
        tester,
        payoutSats: 99700,
        anchoredSats: 99700,
        marketResult: const MarketCheckResult.checked(MarketCheck(
          quotedSats: 200000,
          settledSats: 100000,
          deviation: 0.5,
        )),
      );

      final s = _s(tester);
      expect(find.text(s.invoiceOffMarketTitle), findsOneWidget);
      expect(find.text(s.invoiceContinueAnyway), findsNothing);
      expect(find.byType(AddLightningInvoiceWidget), findsOneWidget);
    });

    testWidgets('says so when the market rate could not be had',
        (tester) async {
      await pumpPayoutScreen(
        tester,
        payoutSats: 99700,
        anchoredSats: 99700,
        marketResult: MarketCheckResult.unavailable,
      );

      expect(find.text(_s(tester).invoiceMarketRateUnavailableTitle),
          findsOneWidget);
    });
  });
}
