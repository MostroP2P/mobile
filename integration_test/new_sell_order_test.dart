import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mostro_mobile/features/order/screens/order_confirmation_screen.dart';
import 'package:mostro_mobile/main.dart' as app;
import 'package:flutter/material.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Create New Sell Order', () {
    testWidgets('User creates a new SELL order with VES=100 and premium=1',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Navigate to the “Add Order” screen
      final createOrderButton = find.byKey(const Key('createOrderButton'));
      expect(createOrderButton, findsOneWidget,
          reason: 'We expect a button that navigates to AddOrderScreen');
      await tester.tap(createOrderButton);
      await tester.pumpAndSettle();

      // Fill out the “NEW ORDER” form

      // Select "SELL" tab
      final sellTabFinder = find.text('SELL');
      if (sellTabFinder.evaluate().isNotEmpty) {
        await tester.tap(sellTabFinder);
        await tester.pumpAndSettle();
      }

      // Tap the fiat code dropdown, select 'VES'
      final fiatCodeDropdown = find.byKey(const Key('fiatCodeDropdown'));
      expect(fiatCodeDropdown, findsOneWidget,
          reason: 'Fiat code dropdown must exist with key(fiatCodeDropdown)');
      await tester.tap(fiatCodeDropdown);
      await tester.pump(const Duration(seconds: 1));

      // Choose 'VES' from the dropdown
      final optionFinder = find.byKey(Key('currency_VES'));
      final scrollableFinder = find.byType(Scrollable).last;

      await tester.scrollUntilVisible(optionFinder, 500.0,
          scrollable: scrollableFinder);
      await tester.pumpAndSettle();

      expect(optionFinder, findsOneWidget);
      await tester.tap(optionFinder);
      await tester.pumpAndSettle();

      expect(find.textContaining('VES'), findsWidgets,
          reason:
              'The CurrencyDropdown should now show VES as the selected currency.');

      // Enter fiat amount '100'
      final fiatAmountField = find.byKey(const Key('fiatAmountField'));
      expect(fiatAmountField, findsOneWidget);
      await tester.enterText(fiatAmountField, '100');
      await tester.pumpAndSettle();

      final fixedSwitch = find.byKey(const Key('fixedSwitch'));
      expect(fixedSwitch, findsOneWidget,
          reason: 'FixedSwitch widget must be present.');
      // Tap the switch to toggle to Market mode.
      await tester.tap(fixedSwitch);
      await tester.pumpAndSettle();

      // Verify that the label next to the switch shows "Market".
      expect(find.text('Market'), findsOneWidget,
          reason: 'The switch label should update to "Market".');

      // Verify that the premium slider is visible instead of the sats text field.
      final premiumSlider = find.byKey(const Key('premiumSlider'));
      expect(premiumSlider, findsOneWidget,
          reason: 'The premium slider must be visible in Market mode.');

      // Set the premium slider to 1%.
      // Assuming the slider range is -10 to 10, with an initial value of 0.
      // We simulate a horizontal drag. The exact offset may need adjusting based on your UI.
      await tester.drag(premiumSlider, const Offset(50, 0));
      await tester.pumpAndSettle();

      // Payment method => 'face to face'
      final paymentMethodField = find.byKey(const Key('paymentMethodField'));
      expect(paymentMethodField, findsOneWidget);
      await tester.enterText(paymentMethodField, 'face to face');
      await tester.pumpAndSettle();

      // Tap "SUBMIT"
      final submitButton = find.text('SUBMIT');
      expect(submitButton, findsOneWidget,
          reason: 'A SUBMIT button is expected');
      await tester.tap(submitButton);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // The app sends a Nostr “Gift wrap” event with the following content:
      //      {
      //        "order": {
      //          "version": 1,
      //          "action": "new-order",
      //          "payload": {
      //            "order": {
      //               "kind": "sell",
      //               "fiat_code": "VES",
      //               "fiat_amount": 100,
      //               "payment_method": "face to face",
      //               "premium": 1,
      //               "status": "pending",
      //               ...
      //            }
      //          }
      //        }
      //      }
      //    We expect a confirmation => UI shows “pending” or success message

      // Verify that the Order Confirmation screen is now displayed.
      expect(find.byType(OrderConfirmationScreen), findsOneWidget);

      final homeButton = find.byKey(const Key('homeButton'));
      expect(homeButton, findsOneWidget, reason: 'A home button is expected');
      await tester.tap(homeButton);
      await tester.pumpAndSettle();
    });

    testWidgets(
        'User creates a new SELL range order with VES=10-20 and premium=1',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Navigate to the “Add Order” screen
      final createOrderButton = find.byKey(const Key('createOrderButton'));
      expect(createOrderButton, findsOneWidget,
          reason: 'We expect a button that navigates to AddOrderScreen');
      await tester.tap(createOrderButton);
      await tester.pumpAndSettle();

      // Fill out the “NEW ORDER” form

      // Select "SELL" tab
      final sellTabFinder = find.text('SELL');
      if (sellTabFinder.evaluate().isNotEmpty) {
        await tester.tap(sellTabFinder);
        await tester.pumpAndSettle();
      }

      // Tap the fiat code dropdown, select 'VES'
      final fiatCodeDropdown = find.byKey(const Key('fiatCodeDropdown'));
      expect(fiatCodeDropdown, findsOneWidget,
          reason: 'Fiat code dropdown must exist with key(fiatCodeDropdown)');
      await tester.tap(fiatCodeDropdown);
      await tester.pump(const Duration(seconds: 1));

      // Choose 'VES' from the dropdown
      final optionFinder = find.byKey(Key('currency_VES'));
      final scrollableFinder = find.byType(Scrollable).last;

      await tester.scrollUntilVisible(optionFinder, 500.0,
          scrollable: scrollableFinder);
      await tester.pumpAndSettle();

      expect(optionFinder, findsOneWidget);
      await tester.tap(optionFinder);
      await tester.pumpAndSettle();

      expect(find.textContaining('VES'), findsWidgets,
          reason:
              'The CurrencyDropdown should now show VES as the selected currency.');

      // Enter fiat amount '100'
      final fiatAmountField = find.byKey(const Key('fiatAmountField'));
      expect(fiatAmountField, findsOneWidget);
      await tester.enterText(fiatAmountField, '10-20');
      await tester.pumpAndSettle();

      final fixedSwitch = find.byKey(const Key('fixedSwitch'));
      expect(fixedSwitch, findsOneWidget,
          reason: 'FixedSwitch widget must be present.');
      // Tap the switch to toggle to Market mode.
      await tester.tap(fixedSwitch);
      await tester.pumpAndSettle();

      // Verify that the label next to the switch shows "Market".
      expect(find.text('Market'), findsOneWidget,
          reason: 'The switch label should update to "Market".');

      // Verify that the premium slider is visible instead of the sats text field.
      final premiumSlider = find.byKey(const Key('premiumSlider'));
      expect(premiumSlider, findsOneWidget,
          reason: 'The premium slider must be visible in Market mode.');

      // Set the premium slider to 1%.
      // Assuming the slider range is -10 to 10, with an initial value of 0.
      // We simulate a horizontal drag. The exact offset may need adjusting based on your UI.
      await tester.drag(premiumSlider, const Offset(50, 0));
      await tester.pumpAndSettle();

      // Payment method => 'face to face'
      final paymentMethodField = find.byKey(const Key('paymentMethodField'));
      expect(paymentMethodField, findsOneWidget);
      await tester.enterText(paymentMethodField, 'face to face');
      await tester.pumpAndSettle();

      // Tap "SUBMIT"
      final submitButton = find.text('SUBMIT');
      expect(submitButton, findsOneWidget,
          reason: 'A SUBMIT button is expected');
      await tester.tap(submitButton);
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // The app sends a Nostr “Gift wrap” event with the following content:
      //      {
      //        "order": {
      //          "version": 1,
      //          "action": "new-order",
      //          "payload": {
      //            "order": {
      //               "kind": "sell",
      //               "fiat_code": "VES",
      //               "min_amount": 10,
      //               "max_amount": 20,
      //               "fiat_amount": 0,
      //               "payment_method": "face to face",
      //               "premium": 1,
      //               "status": "pending",
      //               ...
      //            }
      //          }
      //        }
      //      }
      //    We expect a confirmation => UI shows “pending” or success message

      // Verify that the Order Confirmation screen is now displayed.
      expect(find.byType(OrderConfirmationScreen), findsOneWidget);

      final homeButton = find.byKey(const Key('homeButton'));
      expect(homeButton, findsOneWidget, reason: 'A home button is expected');
      await tester.tap(homeButton);
      await tester.pumpAndSettle();
    });
  });
}
