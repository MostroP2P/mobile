import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/data/enums.dart' as enums;
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';
import 'package:mostro_mobile/features/order/notifiers/order_notifier.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/order/screens/pay_bond_invoice_screen.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/services/mostro_service.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/data/repositories/session_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// The screen is reachable from a notification card, from trade detail and
/// from the maker create flow, so it can be opened at any point of an order's
/// life. "No invoice to show" then means three different things, and telling
/// a maker mid-bond that the invoice expired would make them abandon a valid
/// order (#732 review).
class _NoopSessionStorage implements SessionStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

/// No bond session: the screen only asks for one to pick the maker copy.
class _FixedSessionNotifier extends SessionNotifier {
  _FixedSessionNotifier(Ref ref)
      : super(
          ref,
          _NoopSessionStorage(),
          Settings(
            relays: [],
            fullPrivacyMode: false,
            mostroPublicKey: 'test',
          ),
        ) {
    state = [];
  }
}

class _IdleMostroService extends MostroService {
  _IdleMostroService(super.ref);
}

class _FixedOrderNotifier extends OrderNotifier {
  _FixedOrderNotifier(super.orderId, super.ref, OrderState initial) {
    state = initial;
  }

  @override
  void subscribe() {}

  @override
  Future<void> sync() async {}
}

void main() {
  const orderId = 'order-1';

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  Order order(enums.Status status) => Order(
        id: orderId,
        kind: enums.OrderType.buy,
        status: status,
        amount: 16558,
        fiatCode: 'EUR',
        fiatAmount: 10,
        paymentMethod: 'face to face',
      );

  OrderState stateWith({
    required enums.Status status,
    required enums.Action action,
    String? invoice,
  }) =>
      OrderState(
        status: status,
        action: action,
        order: order(status),
        paymentRequest: invoice == null
            ? null
            : PaymentRequest(order: order(status), lnInvoice: invoice),
      );

  Future<void> pumpScreen(WidgetTester tester, OrderState state) async {
    final router = GoRouter(
      initialLocation: '/pay_bond/$orderId',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const Scaffold()),
        GoRoute(
            path: '/trade_detail/:id', builder: (_, __) => const Scaffold()),
        GoRoute(
          path: '/pay_bond/:orderId',
          builder: (_, __) => const PayBondInvoiceScreen(orderId: orderId),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(SharedPreferencesAsync()),
          sessionNotifierProvider
              .overrideWith((ref) => _FixedSessionNotifier(ref)),
          mostroServiceProvider.overrideWith((ref) => _IdleMostroService(ref)),
          eventProvider(orderId).overrideWithValue(null),
          orderNotifierProvider.overrideWith(
            (ref, id) => _FixedOrderNotifier(id, ref, state),
          ),
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

  testWidgets('renders the QR while the bond invoice is the current one',
      (tester) async {
    await pumpScreen(
      tester,
      stateWith(
        status: enums.Status.waitingTakerBond,
        action: enums.Action.payBondInvoice,
        invoice: 'lnbcbond',
      ),
    );

    expect(find.byType(QrImageView), findsOneWidget);
  });

  testWidgets('waits, without a destructive action, before the invoice arrives',
      (tester) async {
    await pumpScreen(
      tester,
      // The maker create flow lands here while this provider is still at its
      // initial state: the bond message reaches it only after its own sync().
      stateWith(
        status: enums.Status.pending,
        action: enums.Action.newOrder,
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
  });

  testWidgets('sends the user to the trade once the bond has been paid',
      (tester) async {
    await pumpScreen(
      tester,
      stateWith(
        status: enums.Status.waitingBuyerInvoice,
        action: enums.Action.waitingBuyerInvoice,
      ),
    );

    expect(find.byType(QrImageView), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.byType(PayBondInvoiceScreen), findsNothing);
  });

  testWidgets('says the invoice is gone once the take cycle ended',
      (tester) async {
    await pumpScreen(
      tester,
      stateWith(
        status: enums.Status.canceled,
        action: enums.Action.canceled,
      ),
    );

    expect(find.byType(QrImageView), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });
}
