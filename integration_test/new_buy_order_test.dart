import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mostro_mobile/features/order/screens/order_confirmation_screen.dart';
import 'package:mostro_mobile/main.dart' as app;
import 'package:flutter/material.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Create New Buy Order', () {
    testWidgets('User creates a new BUY order with VES=100 and premium=1',
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

      // Select "BUY" tab
      final sellTabFinder = find.text('BUY');
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
      //               "kind": "buy",
      //               "amount": 0,
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

      // Verify that the Order Confirmation screen is now displayed.
      expect(find.byType(OrderConfirmationScreen), findsOneWidget);

      final homeButton = find.byKey(const Key('homeButton'));
      expect(homeButton, findsOneWidget, reason: 'A home button is expected');
      await tester.tap(homeButton);
      await tester.pumpAndSettle();
    });


    testWidgets(
        'User creates a new BUY order with EUR=10 and SATS=1500 using a lightning invoice',
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

      // Select "BUY" tab
      final sellTabFinder = find.text('BUY');
      if (sellTabFinder.evaluate().isNotEmpty) {
        await tester.tap(sellTabFinder);
        await tester.pumpAndSettle();
      }

      // Tap the fiat code dropdown, select 'EUR'
      final fiatCodeDropdown = find.byKey(const Key('fiatCodeDropdown'));
      expect(fiatCodeDropdown, findsOneWidget,
          reason: 'Fiat code dropdown must exist with key(fiatCodeDropdown)');
      await tester.tap(fiatCodeDropdown);
      await tester.pump(const Duration(seconds: 1));

      // Choose 'EUR' from the dropdown
      final optionFinder = find.byKey(Key('currency_EUR'));
      final scrollableFinder = find.byType(Scrollable).last;

      await tester.scrollUntilVisible(optionFinder, 500.0,
          scrollable: scrollableFinder);
      await tester.pumpAndSettle();

      expect(optionFinder, findsOneWidget);
      await tester.tap(optionFinder);
      await tester.pumpAndSettle();

      expect(find.textContaining('EUR'), findsWidgets,
          reason:
              'The CurrencyDropdown should now show EUR as the selected currency.');

      // Enter fiat amount '10'
      final fiatAmountField = find.byKey(const Key('fiatAmountField'));
      expect(fiatAmountField, findsOneWidget);
      await tester.enterText(fiatAmountField, '10');
      await tester.pumpAndSettle();

      // Enter sats amount '15000'
      final satsAmountField = find.byKey(const Key('satsAmountField'));
      expect(satsAmountField, findsOneWidget);
      await tester.enterText(satsAmountField, '15000');
      await tester.pumpAndSettle();

      // LN Address => 'a Lightning Inboice for 15000 sats'
      final lnAddressField = find.byKey(const Key('lightningInvoiceField'));
      expect(lnAddressField, findsOneWidget);
      await tester.enterText(lnAddressField, '');
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
      //               "amount": 15000,
      //               "fiat_code": "EUR",
      //               "fiat_amount": 10,
      //               "payment_method": "face to face",
      //               "premium": 0,
      //               "buyer_invoice": <lightning invoice for 15000 sats>,
      //               "status": "pending",
      //               ...
      //            }
      //          }
      //        }
      //      }

      // Verify that the Order Confirmation screen is now displayed.
      expect(find.byType(OrderConfirmationScreen), findsOneWidget);

      final homeButton = find.byKey(const Key('homeButton'));
      expect(homeButton, findsOneWidget, reason: 'A home button is expected');
      await tester.tap(homeButton);
      await tester.pumpAndSettle();
    });

    testWidgets(
        'User creates a new BUY order with EUR=10 at Market rate using a lightning invoice with no amount',
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

      // Select "BUY" tab
      final sellTabFinder = find.text('BUY');
      if (sellTabFinder.evaluate().isNotEmpty) {
        await tester.tap(sellTabFinder);
        await tester.pumpAndSettle();
      }

      // Tap the fiat code dropdown, select 'EUR'
      final fiatCodeDropdown = find.byKey(const Key('fiatCodeDropdown'));
      expect(fiatCodeDropdown, findsOneWidget,
          reason: 'Fiat code dropdown must exist with key(fiatCodeDropdown)');
      await tester.tap(fiatCodeDropdown);
      await tester.pump(const Duration(seconds: 1));

      // Choose 'EUR' from the dropdown
      final optionFinder = find.byKey(Key('currency_EUR'));
      final scrollableFinder = find.byType(Scrollable).last;

      await tester.scrollUntilVisible(optionFinder, 500.0,
          scrollable: scrollableFinder);
      await tester.pumpAndSettle();

      expect(optionFinder, findsOneWidget);
      await tester.tap(optionFinder);
      await tester.pumpAndSettle();

      expect(find.textContaining('EUR'), findsWidgets,
          reason:
              'The CurrencyDropdown should now show EUR as the selected currency.');

      // Enter fiat amount '10'
      final fiatAmountField = find.byKey(const Key('fiatAmountField'));
      expect(fiatAmountField, findsOneWidget);
      await tester.enterText(fiatAmountField, '10');
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

      // LN Address => 'a Lightning Inboice with no amount'
      final lnAddressField = find.byKey(const Key('lightningInvoiceField'));
      expect(lnAddressField, findsOneWidget);
      await tester.enterText(lnAddressField, '');
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
      //               "amount": 0,
      //               "fiat_code": "EUR",
      //               "fiat_amount": 10,
      //               "payment_method": "face to face",
      //               "premium": 0,
      //               "buyer_invoice": <lightning invoice with no amount>,
      //               "status": "pending",
      //               ...
      //            }
      //          }
      //        }
      //      }

      // Verify that the Order Confirmation screen is now displayed.
      expect(find.byType(OrderConfirmationScreen), findsOneWidget);

      final homeButton = find.byKey(const Key('homeButton'));
      expect(homeButton, findsOneWidget, reason: 'A home button is expected');
      await tester.tap(homeButton);
      await tester.pumpAndSettle();
    });

    testWidgets(
        'User creates a new BUY order with VES=100 and premium=1 using a LN Address',
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

      // Select "BUY" tab
      final sellTabFinder = find.text('BUY');
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

      // LN Address => a working LN address
      final lnAddressField = find.byKey(const Key('lightningInvoiceField'));
      expect(lnAddressField, findsOneWidget);
      await tester.enterText(lnAddressField, 'chebizarro@coinos.io');
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
      //               "amount": 0,
      //               "fiat_code": "VES",
      //               "fiat_amount": 100,
      //               "payment_method": "face to face",
      //               "premium": 1,
      //               "buyer_invoice": "mostro_p2p@ln.tips",
      //               "status": "pending",
      //               ...
      //            }
      //          }
      //        }
      //      }

      // Verify that the Order Confirmation screen is now displayed.
      expect(find.byType(OrderConfirmationScreen), findsOneWidget);

      final homeButton = find.byKey(const Key('homeButton'));
      expect(homeButton, findsOneWidget, reason: 'A home button is expected');
      await tester.tap(homeButton);
      await tester.pumpAndSettle();
    });
  });
}
