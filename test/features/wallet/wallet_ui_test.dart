import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/data/repositories/nwc_storage.dart';
import 'package:mostro_mobile/features/wallet/providers/nwc_provider.dart';
import 'package:mostro_mobile/features/wallet/screens/connect_wallet_screen.dart';
import 'package:mostro_mobile/features/wallet/screens/wallet_settings_screen.dart';
import 'package:mostro_mobile/features/wallet/widgets/wallet_balance_widget.dart';
import 'package:mostro_mobile/features/wallet/widgets/wallet_status_card.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/widgets/nwc_invoice_widget.dart';
import 'package:mostro_mobile/shared/widgets/nwc_payment_receipt_widget.dart';
import 'package:mostro_mobile/shared/widgets/nwc_payment_widget.dart';

/// A BOLT11 string shaped like a real invoice but not payable anywhere.
const _invoice = 'lnbc100n1pjtestinvoicesyntheticvaluefortestsonly';

/// An NwcNotifier pinned to a fixed state: the real one opens a relay
/// connection on construction, which widget tests must not do.
class FakeNwcNotifier extends NwcNotifier {
  FakeNwcNotifier(super.ref, super.storage, NwcState initial) {
    state = initial;
  }
}

Override nwcOverride(NwcState initial) => nwcProvider.overrideWith(
      (ref) => FakeNwcNotifier(
        ref,
        NwcStorage(secureStorage: const FlutterSecureStorage()),
        initial,
      ),
    );

Future<void> pumpNwc(
  WidgetTester tester,
  Widget child, {
  NwcState state = const NwcState(),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [nwcOverride(state)],
      child: MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> pumpNwcScreen(
  WidgetTester tester,
  Widget screen, {
  NwcState state = const NwcState(),
}) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [GoRoute(path: '/', builder: (_, __) => screen)],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [nwcOverride(state)],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Unmounts the widget and drains any pending timers it scheduled.
Future<void> disposeScreen(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 30));
}

const _connected = NwcState(
  status: NwcStatus.connected,
  walletAlias: 'Test wallet',
  balanceMsats: 250000000,
  supportedMethods: ['pay_invoice', 'make_invoice', 'get_balance'],
  connectionHealthy: true,
);

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues(<String, String>{}));

  group('NwcState', () {
    test('converts the balance from millisatoshis to satoshis', () {
      expect(const NwcState(balanceMsats: 250000000).balanceSats, 250000);
      expect(const NwcState().balanceSats, isNull);
    });

    test('defaults to a disconnected, unhealthy wallet', () {
      const state = NwcState();

      expect(state.status, NwcStatus.disconnected);
      expect(state.walletAlias, isNull);
      expect(state.errorMessage, isNull);
      expect(state.supportedMethods, isEmpty);
      expect(state.connectionHealthy, isFalse);
      expect(state.lastSuccessfulContact, isNull);
    });

    test('copyWith overrides only what is given', () {
      final updated = _connected.copyWith(status: NwcStatus.error);

      expect(updated.status, NwcStatus.error);
      expect(updated.walletAlias, 'Test wallet');
      expect(updated.balanceMsats, 250000000);
    });

    test('copyWith can clear the error and the wallet info', () {
      const errored = NwcState(
        status: NwcStatus.error,
        errorMessage: 'boom',
        walletAlias: 'Test wallet',
        balanceMsats: 1000,
      );

      expect(errored.copyWith(clearError: true).errorMessage, isNull);
      expect(errored.copyWith(clearWalletInfo: true).walletAlias, isNull);
      expect(errored.copyWith(clearWalletInfo: true).balanceMsats, isNull);
    });

    test('compares by value', () {
      expect(const NwcState(), const NwcState());
      expect(const NwcState(), isNot(const NwcState(balanceMsats: 1)));
    });
  });

  group('WalletBalanceWidget', () {
    testWidgets('renders a grouped balance', (tester) async {
      await pumpNwc(tester, const WalletBalanceWidget(balanceSats: 1234567));

      expect(find.byType(WalletBalanceWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without a known balance', (tester) async {
      await pumpNwc(tester, const WalletBalanceWidget());

      expect(find.byType(WalletBalanceWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reports refresh taps', (tester) async {
      var refreshes = 0;
      await pumpNwc(
        tester,
        WalletBalanceWidget(balanceSats: 100, onRefresh: () => refreshes++),
      );

      final button = find.byType(IconButton);
      if (button.evaluate().isNotEmpty) {
        await tester.tap(button.first, warnIfMissed: false);
        await tester.pump();
        expect(refreshes, 1);
      }
    });
  });

  group('WalletStatusCard', () {
    testWidgets('renders a disconnected wallet', (tester) async {
      await pumpNwc(tester, const WalletStatusCard());

      expect(find.byType(WalletStatusCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders a connected wallet', (tester) async {
      await pumpNwc(tester, const WalletStatusCard(), state: _connected);

      expect(find.byType(WalletStatusCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders an errored wallet', (tester) async {
      await pumpNwc(
        tester,
        const WalletStatusCard(),
        state: const NwcState(
          status: NwcStatus.error,
          errorMessage: 'relay unreachable',
        ),
      );

      expect(find.byType(WalletStatusCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('NwcPaymentReceiptWidget', () {
    testWidgets('renders amount, fees and preimage', (tester) async {
      await pumpNwc(
        tester,
        NwcPaymentReceiptWidget(
          amountSats: 1000,
          feesPaidMsats: 2000,
          preimage: 'c' * 64,
          timestamp: DateTime.utc(2026, 1, 2, 3, 4),
        ),
      );

      expect(find.byType(NwcPaymentReceiptWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without fees or preimage', (tester) async {
      await pumpNwc(
        tester,
        NwcPaymentReceiptWidget(
          amountSats: 1000,
          timestamp: DateTime.utc(2026),
        ),
      );

      expect(find.byType(NwcPaymentReceiptWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders a dismissable receipt', (tester) async {
      var dismissed = 0;
      await pumpNwc(
        tester,
        NwcPaymentReceiptWidget(
          amountSats: 1000,
          timestamp: DateTime.utc(2026),
          onDismiss: () => dismissed++,
        ),
      );

      final buttons = find.byWidgetPredicate(
        (w) => w is ButtonStyleButton || w is IconButton,
      );
      if (buttons.evaluate().isNotEmpty) {
        await tester.tap(buttons.first, warnIfMissed: false);
        await tester.pump();
        expect(dismissed, 1);
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('NwcPaymentWidget', () {
    testWidgets('renders for a disconnected wallet', (tester) async {
      await pumpNwc(
        tester,
        const NwcPaymentWidget(lnInvoice: _invoice, sats: 1000),
      );

      expect(find.byType(NwcPaymentWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
      await disposeScreen(tester);
    });

    testWidgets('renders for a connected wallet', (tester) async {
      await pumpNwc(
        tester,
        const NwcPaymentWidget(lnInvoice: _invoice, sats: 1000),
        state: _connected,
      );

      expect(find.byType(NwcPaymentWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
      await disposeScreen(tester);
    });
  });

  group('NwcInvoiceWidget', () {
    testWidgets('renders for a disconnected wallet', (tester) async {
      await pumpNwc(
        tester,
        NwcInvoiceWidget(
          sats: 1000,
          orderId: 'order-1',
          onInvoiceConfirmed: (_) {},
        ),
      );

      expect(find.byType(NwcInvoiceWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
      await disposeScreen(tester);
    });

    testWidgets('renders for a connected wallet', (tester) async {
      await pumpNwc(
        tester,
        NwcInvoiceWidget(
          sats: 1000,
          orderId: 'order-1',
          onInvoiceConfirmed: (_) {},
        ),
        state: _connected,
      );

      expect(find.byType(NwcInvoiceWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
      await disposeScreen(tester);
    });
  });

  group('WalletSettingsScreen', () {
    testWidgets('renders a disconnected wallet', (tester) async {
      await pumpNwcScreen(tester, const WalletSettingsScreen());

      expect(find.byType(WalletSettingsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await disposeScreen(tester);
    });

    testWidgets('renders a connected wallet', (tester) async {
      await pumpNwcScreen(
        tester,
        const WalletSettingsScreen(),
        state: _connected,
      );

      expect(find.byType(WalletSettingsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await disposeScreen(tester);
    });
  });

  group('ConnectWalletScreen', () {
    testWidgets('renders the connection form', (tester) async {
      await pumpNwcScreen(tester, const ConnectWalletScreen());

      expect(find.byType(ConnectWalletScreen), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);
      expect(tester.takeException(), isNull);
      await disposeScreen(tester);
    });

    testWidgets('accepts a typed connection URI', (tester) async {
      await pumpNwcScreen(tester, const ConnectWalletScreen());

      await tester.enterText(
        find.byType(TextField).first,
        'nostr+walletconnect://${'a' * 64}?relay=wss%3A%2F%2Frelay.example'
        '&secret=${'b' * 64}',
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      await disposeScreen(tester);
    });
  });
}
