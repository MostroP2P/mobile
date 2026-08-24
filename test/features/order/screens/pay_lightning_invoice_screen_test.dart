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

/// A data part long enough to look real; only the prefix is read.
const _data = 'pvjluezpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfq';

/// [sats] satoshis expressed the way an invoice does, in nano-bitcoin.
String invoiceFor(int sats) => 'lnbc${sats * 10}n1$_data';

/// Holds a fixed [OrderState] without any of the notifier's real machinery,
/// which reaches for sessions, storage and a live subscription.
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

Future<void> pumpPayScreen(
  WidgetTester tester, {
  required String lnInvoice,
  required int messageSats,
  int? anchoredSats,
  MarketCheck? market,
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
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const PayLightningInvoiceScreen(orderId: _orderId),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        orderNotifierProvider
            .overrideWith((ref, id) => _StubOrderNotifier(state)),
        nwcProvider.overrideWith((ref) => _StubNwcNotifier()),
        sessionProvider.overrideWith((ref, id) => null),
        anchoredSellerAmountProvider.overrideWith((ref, id) => anchoredSats),
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
}

/// The refusal box, whichever case produced it.
Finder refusalNotice(WidgetTester tester) => find.text(
      S.of(tester.element(find.byType(Scaffold)))!.invoiceNotPayableTitle,
    );

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

      final s = S.of(tester.element(find.byType(Scaffold)))!;
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

      final s = S.of(tester.element(find.byType(Scaffold)))!;
      expect(find.text(s.invoiceTermsUnverifiedTitle), findsNothing);
      expect(find.text(s.invoiceOffMarketTitle), findsNothing);
    });

    testWidgets('cautions when the order settles off the market rate',
        (tester) async {
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

      final s = S.of(tester.element(find.byType(Scaffold)))!;
      expect(find.text(s.invoiceOffMarketTitle), findsOneWidget);
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

      final s = S.of(tester.element(find.byType(Scaffold)))!;
      expect(find.text(s.invoiceOffMarketTitle), findsNothing);
    });
  });
}
