import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Create Orders with mocked providers', () {
    testWidgets('User creates BUY order with VES=100 at premium 1', (tester) async {
      await pumpTestApp(tester);

      final createOrderButton = find.byKey(const Key('addOrderButton'));
      expect(createOrderButton, findsOneWidget);
      await tester.tap(createOrderButton);
      await tester.pumpAndSettle();

      final buyButton = find.byKey(const Key('buyButton'));
      expect(buyButton, findsOneWidget);
      await tester.tap(buyButton);
      await tester.pumpAndSettle();

      final fiatCodeDropdown = find.byKey(const Key('fiatCodeDropdown'));
      await tester.tap(fiatCodeDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('currency_VES')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('fiatAmountField')), '100');
      await tester.pumpAndSettle();

      // Skipping tap on 'fixedSwitch' because default is already market and premium slider is visible
      final premiumSlider = find.byKey(const Key('premiumSlider'));
      await tester.drag(premiumSlider, const Offset(50, 0));
      await tester.pumpAndSettle();

      //final paymentMethodField = find.byKey(const Key('paymentMethodField'));
      //await tester.enterText(paymentMethodField, 'face to face');
      //await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('submitOrderButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('homeButton')), findsOneWidget);
    });

    testWidgets('User creates SELL order with VES=100 at premium 1', (tester) async {
      await pumpTestApp(tester);

      final createOrderButton = find.byKey(const Key('addOrderButton'));
      expect(createOrderButton, findsOneWidget);
      await tester.tap(createOrderButton);
      await tester.pumpAndSettle();

      final sellButton = find.byKey(const Key('sellButton'));
      expect(sellButton, findsOneWidget);
      await tester.tap(sellButton);
      await tester.pumpAndSettle();

      final fiatCodeDropdown = find.byKey(const Key('fiatCodeDropdown'));
      await tester.tap(fiatCodeDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('currency_VES')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('fiatAmountField')), '100');
      await tester.pumpAndSettle();

      final fixedSwitch = find.byKey(const Key('fixedSwitch'));
      await tester.tap(fixedSwitch);
      await tester.pumpAndSettle();

      final premiumSlider = find.byKey(const Key('premiumSlider'));
      await tester.drag(premiumSlider, const Offset(50, 0));
      await tester.pumpAndSettle();

      final paymentMethodField = find.byKey(const Key('paymentMethodField'));
      await tester.enterText(paymentMethodField, 'face to face');
      await tester.pumpAndSettle();

      await tester.tap(find.text('SUBMIT'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('homeButton')), findsOneWidget);
    });
  });
}
