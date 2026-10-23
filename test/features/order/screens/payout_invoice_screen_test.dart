import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/enums.dart' as enums;
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/features/order/screens/payout_invoice_screen.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// The node pays the order amount minus its fee and rejects any invoice worth
/// anything else, so the figure this screen prints is the difference between a
/// payout that works and one refused with no explanation (#748).
void main() {
  const orderId = 'order-1';

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  Order payoutOrder(int amount) => Order(
        id: orderId,
        kind: enums.OrderType.sell,
        status: enums.Status.settledHoldInvoice,
        amount: amount,
        fiatCode: 'EUR',
        fiatAmount: 710,
        paymentMethod: 'SEPA instant',
      );

  Future<void> pumpScreen(WidgetTester tester, Order? order) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(SharedPreferencesAsync()),
        ],
        child: MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: PayoutInvoiceScreen(orderId: orderId, order: order),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('asks for the payout amount it was given', (tester) async {
    await pumpScreen(tester, payoutOrder(935138));

    final context = tester.element(find.byType(PayoutInvoiceScreen));
    final s = S.of(context)!;
    expect(
      find.text(s.payoutInvoiceInstruction('935138', '710', 'EUR')),
      findsOneWidget,
    );
  });

  // A fresh install that only ran a restore has no message stating the payout
  // amount. Printing 0 — or the order's gross — sends the user into a loop of
  // rejections, so the screen asks for an amountless invoice instead, which
  // the node accepts.
  testWidgets('asks for an amountless invoice when the amount is unknown',
      (tester) async {
    await pumpScreen(tester, null);

    final context = tester.element(find.byType(PayoutInvoiceScreen));
    final s = S.of(context)!;
    expect(find.text(s.payoutInvoiceInstructionNoAmount), findsOneWidget);
    expect(find.textContaining('0 sats'), findsNothing);
  });
}
