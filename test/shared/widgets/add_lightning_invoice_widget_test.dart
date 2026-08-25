import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/widgets/add_lightning_invoice_widget.dart';

void main() {
  group('AddLightningInvoiceWidget cancel button', () {
    Widget harness(Widget child) => MaterialApp(
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: Scaffold(body: child),
        );

    testWidgets('is hidden when no cancel callback is given', (tester) async {
      await tester.pumpWidget(harness(AddLightningInvoiceWidget(
        controller: TextEditingController(),
        onSubmit: () {},
        amount: 1000,
        fiatAmount: '10',
        fiatCode: 'USD',
        orderId: 'order-1',
      )));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cancelInvoiceButton')), findsNothing);
      expect(find.byKey(const Key('submitInvoiceButton')), findsOneWidget);
    });

    testWidgets('is shown when a cancel callback is given', (tester) async {
      await tester.pumpWidget(harness(AddLightningInvoiceWidget(
        controller: TextEditingController(),
        onSubmit: () {},
        onCancel: () {},
        amount: 1000,
        fiatAmount: '10',
        fiatCode: 'USD',
        orderId: 'order-1',
      )));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cancelInvoiceButton')), findsOneWidget);
    });
  });
}
