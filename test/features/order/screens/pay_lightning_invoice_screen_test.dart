import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as mostro;
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/payment_request.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';
import 'package:mostro_mobile/features/order/notifiers/order_notifier.dart';
import 'package:mostro_mobile/features/order/providers/market_check_provider.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/order/providers/settlement_anchor_provider.dart';
import 'package:mostro_mobile/features/order/screens/pay_lightning_invoice_screen.dart';
import 'package:mostro_mobile/features/wallet/providers/nwc_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/widgets/pay_lightning_invoice_widget.dart';
import 'package:mostro_mobile/shared/utils/market_quote.dart';

const _orderId = 'order-1';

/// Feeds [marketCheckProvider] so a test can move the quote under a screen
/// that is already mounted, the way a node republish or a rate refresh does.
final _marketSource = StateProvider<MarketCheckResult>(
    (ref) => MarketCheckResult.notApplicable);

/// A data part long enough to look real; only the prefix is read.
const _data = 'pvjluezpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfq';

/// [sats] satoshis expressed the way an invoice does, in nano-bitcoin.
String invoiceFor(int sats) => 'lnbc${sats * 10}n1$_data';

/// Holds a fixed [OrderState] without any of the notifier's real machinery,
/// which reaches for sessions, storage and a live subscription.
class _StubOrderNotifier extends StateNotifier<OrderState>
    implements OrderNotifier {
  _StubOrderNotifier(super.state, {this.cancelFails = false});

  final bool cancelFails;

  @override
  Future<void> cancelOrder() async {
    if (cancelFails) throw Exception('relay unreachable');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Reports a disconnected wallet, so the screen takes the manual flow.
class _StubNwcNotifier extends StateNotifier<NwcState> implements NwcNotifier {
  _StubNwcNotifier() : super(const NwcState());

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<void> pumpPayScreen(
  WidgetTester tester, {
  required String lnInvoice,
  required int messageSats,
  int? anchoredSats,
  MarketCheck? market,
  MarketCheckResult? marketResult,
  bool cancelFails = false,
}) async {
  final state = OrderState(
    status: Status.waitingPayment,
    action: mostro.Action.payInvoice,
    order: Order(
      id: _orderId,
      kind: OrderType.sell,
      status: Status.waitingPayment,
      amount: messageSats,
      fiatCode: 'USD',
      fiatAmount: 100,
      paymentMethod: 'bank',
      premium: 0,
    ),
    paymentRequest: PaymentRequest(lnInvoice: lnInvoice),
  );

  final router = GoRouter(
    initialLocation: '/pay',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('home')),
      ),
      GoRoute(
        path: '/pay',
        builder: (_, __) => const PayLightningInvoiceScreen(orderId: _orderId),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        orderNotifierProvider
            .overrideWith(
                (ref, id) => _StubOrderNotifier(state, cancelFails: cancelFails)),
        nwcProvider.overrideWith((ref) => _StubNwcNotifier()),
        sessionProvider.overrideWith((ref, id) => null),
        anchoredSellerAmountProvider.overrideWith((ref, id) => anchoredSats),
        _marketSource.overrideWith((ref) =>
            marketResult ??
            (market == null
                ? MarketCheckResult.notApplicable
                : MarketCheckResult.checked(market))),
        marketCheckProvider.overrideWith((ref, id) => ref.watch(_marketSource)),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
      ),
    ),
  );
  await tester.pump();
}

S _s(WidgetTester tester) =>
    S.of(tester.element(find.byType(PayLightningInvoiceScreen)))!;

/// Replaces the quote on the mounted screen and lets it rebuild.
Future<void> moveMarketTo(WidgetTester tester, MarketCheck market) =>
    moveMarketResultTo(tester, MarketCheckResult.checked(market));

/// Replaces the whole check outcome on the mounted screen and lets it rebuild.
Future<void> moveMarketResultTo(
    WidgetTester tester, MarketCheckResult result) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(PayLightningInvoiceScreen)),
  );
  container.read(_marketSource.notifier).state = result;
  await tester.pump();
}

/// The terms refusal box, whichever case produced it.
Finder refusalNotice(WidgetTester tester) =>
    find.text(_s(tester).invoiceNotPayableTitle);

void main() {
  group('PayLightningInvoiceScreen gating', () {
    testWidgets('refuses an invoice that asks for more than the order says',
        (tester) async {
      // The finding's scenario: the message shows 50,000 and carries an
      // invoice for 500,000.
      await pumpPayScreen(
        tester,
        lnInvoice: invoiceFor(500000),
        messageSats: 50000,
        anchoredSats: 50000,
      );

      expect(refusalNotice(tester), findsOneWidget);
      expect(find.byType(PayLightningInvoiceWidget), findsNothing);
    });

    testWidgets('pays an invoice that agrees with the signed terms',
        (tester) async {
      await pumpPayScreen(
        tester,
        lnInvoice: invoiceFor(50300),
        messageSats: 50300,
        anchoredSats: 50300,
      );

      expect(refusalNotice(tester), findsNothing);
    });

    testWidgets('refuses an invoice that sets no amount', (tester) async {
      await pumpPayScreen(
        tester,
        lnInvoice: 'lnbc1$_data',
        messageSats: 50000,
        anchoredSats: 50000,
      );

      expect(refusalNotice(tester), findsOneWidget);
    });

    testWidgets('refuses an invoice it cannot read', (tester) async {
      await pumpPayScreen(
        tester,
        lnInvoice: 'not-an-invoice',
        messageSats: 50000,
        anchoredSats: 50000,
      );

      expect(refusalNotice(tester), findsOneWidget);
    });

    testWidgets('shows the amount the invoice asks for, not the message figure',
        (tester) async {
      // The invoice agrees with the signed terms, so nothing is blocked. The
      // message's own figure disagrees with both, and a wallet scanning the
      // QR code would pay the invoice — so that is the figure the screen has
      // to print beside it.
      await pumpPayScreen(
        tester,
        lnInvoice: invoiceFor(50300),
        messageSats: 99999,
        anchoredSats: 50300,
      );

      expect(find.textContaining('50300'), findsWidgets);
      expect(find.textContaining('99999'), findsNothing);
    });

    testWidgets('cautions when the signed terms could not be derived',
        (tester) async {
      await pumpPayScreen(
        tester,
        lnInvoice: invoiceFor(50000),
        messageSats: 50000,
        anchoredSats: null,
      );

      final s = _s(tester);
      expect(find.text(s.invoiceTermsUnverifiedTitle), findsOneWidget);
      expect(refusalNotice(tester), findsNothing);
    });

    testWidgets('says nothing extra when the terms were derived',
        (tester) async {
      await pumpPayScreen(
        tester,
        lnInvoice: invoiceFor(50300),
        messageSats: 50300,
        anchoredSats: 50300,
      );

      final s = _s(tester);
      expect(find.text(s.invoiceTermsUnverifiedTitle), findsNothing);
      expect(find.text(s.invoiceOffMarketTitle), findsNothing);
    });

    testWidgets('cautions when the gap runs in the seller\'s favour',
        (tester) async {
      // The seller gives up fewer sats than the market says the fiat is
      // worth. Worth naming, not worth stopping.
      await pumpPayScreen(
        tester,
        lnInvoice: invoiceFor(50000),
        messageSats: 50000,
        anchoredSats: 50000,
        market: const MarketCheck(
          quotedSats: 100000,
          settledSats: 50000,
          deviation: 0.5,
        ),
      );

      final s = _s(tester);
      expect(find.text(s.invoiceOffMarketTitle), findsOneWidget);
      expect(find.text(s.invoiceContinueAnyway), findsNothing);
      expect(find.byType(PayLightningInvoiceWidget), findsOneWidget);
    });

    testWidgets('refuses when the gap runs against the seller', (tester) async {
      // The seller would give up twice the sats the market prices the fiat
      // at, which is the direction a skim takes.
      await pumpPayScreen(
        tester,
        lnInvoice: invoiceFor(100000),
        messageSats: 100000,
        anchoredSats: 100000,
        market: const MarketCheck(
          quotedSats: 50000,
          settledSats: 100000,
          deviation: 1.0,
        ),
      );

      final s = _s(tester);
      expect(find.text(s.invoiceOffMarketTitle), findsOneWidget);
      expect(find.byType(PayLightningInvoiceWidget), findsNothing);
      expect(find.text(s.invoiceContinueAnyway), findsOneWidget);
      expect(find.text(s.cancel), findsOneWidget);
    });

    testWidgets('lets the seller pay a refused settlement deliberately',
        (tester) async {
      await pumpPayScreen(
        tester,
        lnInvoice: invoiceFor(100000),
        messageSats: 100000,
        anchoredSats: 100000,
        market: const MarketCheck(
          quotedSats: 50000,
          settledSats: 100000,
          deviation: 1.0,
        ),
      );

      await tester.tap(find.text(_s(tester).invoiceContinueAnyway));
      await tester.pumpAndSettle();

      final s = _s(tester);
      expect(find.byType(PayLightningInvoiceWidget), findsOneWidget);
      // The gap does not stop being true once it has been accepted.
      expect(find.text(s.invoiceOffMarketTitle), findsOneWidget);
    });

    testWidgets('cautions rather than refusing when the order carries no amount',
        (tester) async {
      // Nothing about the invoice contradicts the order; there is simply no
      // order figure to check it against. Refusing there would make an absent
      // term stronger evidence than a disagreeing one.
      await pumpPayScreen(
        tester,
        lnInvoice: invoiceFor(100000),
        messageSats: 0,
        anchoredSats: null,
      );

      final s = _s(tester);
      expect(refusalNotice(tester), findsNothing);
      expect(find.text(s.invoiceTermsUnverifiedTitle), findsOneWidget);
      expect(find.byType(PayLightningInvoiceWidget), findsOneWidget);
    });

    testWidgets('holds the pay button while the rate is still in flight',
        (tester) async {
      await pumpPayScreen(
        tester,
        lnInvoice: invoiceFor(100000),
        messageSats: 100000,
        anchoredSats: 100000,
        marketResult: MarketCheckResult.loading,
      );

      expect(find.byType(PayLightningInvoiceWidget), findsNothing);
      expect(find.text(_s(tester).invoiceCheckingMarketRate), findsOneWidget);

      // The answer lands and the flow opens on it.
      await moveMarketResultTo(
        tester,
        const MarketCheckResult.checked(MarketCheck(
          quotedSats: 100100,
          settledSats: 100000,
          deviation: 0.001,
        )),
      );

      expect(find.byType(PayLightningInvoiceWidget), findsOneWidget);
    });

    testWidgets('keeps cancel reachable while the rate is in flight',
        (tester) async {
      // Every other branch offers it. A request that never comes back would
      // otherwise leave the user with no way forward and no way out.
      await pumpPayScreen(
        tester,
        lnInvoice: invoiceFor(100000),
        messageSats: 100000,
        anchoredSats: 100000,
        marketResult: MarketCheckResult.loading,
      );

      expect(find.text(_s(tester).cancel), findsOneWidget);
    });

    testWidgets('says so when the rate could not be had, without refusing',
        (tester) async {
      // An unreachable third party is not evidence against a settlement, so
      // it is named rather than used to stop the trade.
      await pumpPayScreen(
        tester,
        lnInvoice: invoiceFor(100000),
        messageSats: 100000,
        anchoredSats: 100000,
        marketResult: MarketCheckResult.unavailable,
      );

      final s = _s(tester);
      expect(find.text(s.invoiceMarketRateUnavailableTitle), findsOneWidget);
      expect(find.byType(PayLightningInvoiceWidget), findsOneWidget);
    });

    testWidgets('does not carry an override onto a quote that has changed',
        (tester) async {
      // The user accepts a gap of 100000 against a 50000 quote. The node then
      // republishes and the settlement doubles again. A route-wide flag stayed
      // true through that and left the pay button live under a caution.
      await pumpPayScreen(
        tester,
        lnInvoice: invoiceFor(100000),
        messageSats: 100000,
        anchoredSats: 100000,
        market: const MarketCheck(
          quotedSats: 50000,
          settledSats: 100000,
          deviation: 1.0,
        ),
      );

      await tester.tap(find.text(_s(tester).invoiceContinueAnyway));
      await tester.pumpAndSettle();
      expect(find.byType(PayLightningInvoiceWidget), findsOneWidget);

      await moveMarketTo(
        tester,
        const MarketCheck(
          quotedSats: 50000,
          settledSats: 200000,
          deviation: 3.0,
        ),
      );

      final s = _s(tester);
      expect(find.byType(PayLightningInvoiceWidget), findsNothing);
      expect(find.text(s.invoiceOffMarketTitle), findsOneWidget);
      expect(find.text(s.invoiceContinueAnyway), findsOneWidget);
    });

    testWidgets('keeps the override while the quote it was given for holds',
        (tester) async {
      const accepted = MarketCheck(
        quotedSats: 50000,
        settledSats: 100000,
        deviation: 1.0,
      );
      await pumpPayScreen(
        tester,
        lnInvoice: invoiceFor(100000),
        messageSats: 100000,
        anchoredSats: 100000,
        market: accepted,
      );

      await tester.tap(find.text(_s(tester).invoiceContinueAnyway));
      await tester.pumpAndSettle();

      // A rebuild carrying the same figures is the same quote, so the user is
      // not asked again.
      await moveMarketTo(tester, accepted);

      expect(find.byType(PayLightningInvoiceWidget), findsOneWidget);
    });

    testWidgets('stays quiet when the settlement is on the market rate',
        (tester) async {
      await pumpPayScreen(
        tester,
        lnInvoice: invoiceFor(50000),
        messageSats: 50000,
        anchoredSats: 50000,
        market: const MarketCheck(
          quotedSats: 50100,
          settledSats: 50000,
          deviation: 0.002,
        ),
      );

      final s = _s(tester);
      expect(find.text(s.invoiceOffMarketTitle), findsNothing);
    });

    testWidgets('leaves the screen once cancellation goes through',
        (tester) async {
      await pumpPayScreen(
        tester,
        lnInvoice: invoiceFor(500000),
        messageSats: 50000,
        anchoredSats: 50000,
      );

      await tester.tap(find.text(_s(tester).cancel));
      await tester.pumpAndSettle();

      expect(find.byType(PayLightningInvoiceScreen), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('keeps the screen and reports a cancellation that failed',
        (tester) async {
      // Cancel is the only action offered after a refusal. Navigating away
      // before the cancellation lands would hide the failure and leave the
      // trade active with nothing left to act on.
      await pumpPayScreen(
        tester,
        lnInvoice: invoiceFor(500000),
        messageSats: 50000,
        anchoredSats: 50000,
        cancelFails: true,
      );

      await tester.tap(find.text(_s(tester).cancel));
      await tester.pump();
      await tester.pump();

      expect(find.byType(PayLightningInvoiceScreen), findsOneWidget);
      expect(find.textContaining('relay unreachable'), findsOneWidget);
    });
  });
}
