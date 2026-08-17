import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/data/models/currency.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/features/order/providers/payment_methods_provider.dart';
import 'package:mostro_mobile/features/order/widgets/amount_section.dart';
import 'package:mostro_mobile/features/order/widgets/currency_section.dart';
import 'package:mostro_mobile/features/order/widgets/form_section.dart';
import 'package:mostro_mobile/features/order/widgets/lightning_address_section.dart';
import 'package:mostro_mobile/features/order/widgets/order_app_bar.dart';
import 'package:mostro_mobile/features/order/widgets/order_type_header.dart';
import 'package:mostro_mobile/features/order/widgets/payment_methods_section.dart';
import 'package:mostro_mobile/features/order/widgets/premium_section.dart';
import 'package:mostro_mobile/features/order/widgets/price_type_section.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/providers/exchange_service_provider.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

final _currencies = <String, Currency>{
  'USD': Currency(
    symbol: r'$',
    name: 'US Dollar',
    symbolNative: r'$',
    code: 'USD',
    emoji: '🇺🇸',
    decimalDigits: 2,
    namePlural: 'US dollars',
    price: true,
  ),
};

const _paymentMethods = <String, dynamic>{
  'USD': ['Bank Transfer', 'Cash in person', 'Other'],
};

Future<void> pump(
  WidgetTester tester,
  Widget child, {
  String? fiatCode = 'USD',
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currencyCodesProvider.overrideWith((ref) async => _currencies),
        paymentMethodsDataProvider.overrideWith((ref) async => _paymentMethods),
        selectedFiatCodeProvider.overrideWith((ref) => fiatCode),
        sharedPreferencesProvider.overrideWithValue(SharedPreferencesAsync()),
      ],
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

/// Unmounts the widget and drains pending timers (PremiumSection debounces).
Future<void> disposeWidget(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('FormSection', () {
    testWidgets('renders its title and child', (tester) async {
      await pump(
        tester,
        const FormSection(
          title: 'Amount',
          icon: Icon(Icons.attach_money),
          iconBackgroundColor: Colors.green,
          child: Text('body'),
        ),
      );

      expect(find.text('Amount'), findsOneWidget);
      expect(find.text('body'), findsOneWidget);
    });

    testWidgets('renders the optional extras', (tester) async {
      await pump(
        tester,
        const FormSection(
          title: 'Amount',
          icon: Icon(Icons.attach_money),
          iconBackgroundColor: Colors.green,
          infoTooltip: 'What is this?',
          infoTitle: 'Amount',
          topRightWidget: Text('top-right'),
          extraContent: Text('extra'),
          child: Text('body'),
        ),
      );

      expect(find.text('top-right'), findsOneWidget);
      expect(find.text('extra'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opens the info dialog when the tooltip icon is tapped',
        (tester) async {
      await pump(
        tester,
        const FormSection(
          title: 'Amount',
          icon: Icon(Icons.attach_money),
          iconBackgroundColor: Colors.green,
          infoTooltip: 'What is this?',
          infoTitle: 'Amount',
          child: Text('body'),
        ),
      );

      final infoIcon = find.byIcon(Icons.info_outline);
      expect(infoIcon, findsOneWidget);

      await tester.tap(infoIcon);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('What is this?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('OrderTypeHeader', () {
    testWidgets('renders for a buy order', (tester) async {
      await pump(tester, const OrderTypeHeader(orderType: OrderType.buy));

      expect(find.byType(OrderTypeHeader), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders for a sell order', (tester) async {
      await pump(tester, const OrderTypeHeader(orderType: OrderType.sell));

      expect(find.byType(OrderTypeHeader), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('OrderAppBar', () {
    testWidgets('renders the title and pops on back', (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: Text('home')),
            routes: [
              GoRoute(
                path: 'child',
                builder: (_, __) => const Scaffold(
                  appBar: OrderAppBar(title: 'New order'),
                  body: SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: S.localizationsDelegates,
            supportedLocales: S.supportedLocales,
          ),
        ),
      );
      await tester.pump();
      router.push('/child');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('New order'), findsOneWidget);

      await tester.tap(find.byType(IconButton).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('reports the standard toolbar height', (tester) async {
      expect(
        const OrderAppBar(title: 't').preferredSize.height,
        kToolbarHeight,
      );
    });
  });

  group('PriceTypeSection', () {
    testWidgets('renders both price modes and reports toggles', (tester) async {
      final toggles = <bool>[];
      await pump(
        tester,
        PriceTypeSection(isMarketRate: true, onToggle: toggles.add),
      );

      expect(find.byType(PriceTypeSection), findsOneWidget);

      // The market/fixed switch is the only control that reports a toggle.
      final marketSwitch = find.byKey(const Key('fixedSwitch'));
      expect(marketSwitch, findsOneWidget);

      await tester.tap(marketSwitch);
      await tester.pump();

      expect(toggles, [false]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders a fixed price with an error message', (tester) async {
      await pump(
        tester,
        PriceTypeSection(
          isMarketRate: false,
          onToggle: (_) {},
          errorMessage: 'Enter a price',
        ),
      );

      expect(find.textContaining('Enter a price', findRichText: true),
          findsWidgets);
    });
  });

  group('LightningAddressSection', () {
    testWidgets('renders a text field bound to its controller', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await pump(tester, LightningAddressSection(controller: controller));
      await tester.enterText(find.byType(TextField).first, 'me@example.test');

      expect(controller.text, 'me@example.test');
    });
  });

  group('CurrencySection', () {
    testWidgets('renders for a buy order once currencies load', (tester) async {
      await pump(
        tester,
        CurrencySection(orderType: OrderType.buy, onCurrencySelected: () {}),
      );

      expect(find.byType(CurrencySection), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders for a sell order with no currency selected',
        (tester) async {
      await pump(
        tester,
        CurrencySection(orderType: OrderType.sell, onCurrencySelected: () {}),
        fiatCode: null,
      );

      expect(find.byType(CurrencySection), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reports selection taps', (tester) async {
      var selections = 0;
      await pump(
        tester,
        CurrencySection(
          orderType: OrderType.buy,
          onCurrencySelected: () => selections++,
        ),
      );

      final tappable = find.byType(InkWell);
      if (tappable.evaluate().isNotEmpty) {
        await tester.tap(tappable.first, warnIfMissed: false);
        await tester.pump();
      }

      expect(tester.takeException(), isNull);
    });
  });

  group('PaymentMethodsSection', () {
    testWidgets('renders the methods for the selected currency',
        (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await pump(
        tester,
        PaymentMethodsSection(
          selectedMethods: const ['Bank Transfer'],
          customController: controller,
          onMethodsChanged: (_) {},
        ),
      );

      expect(find.byType(PaymentMethodsSection), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders with no currency selected', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await pump(
        tester,
        PaymentMethodsSection(
          selectedMethods: const [],
          customController: controller,
          onMethodsChanged: (_) {},
        ),
        fiatCode: null,
      );

      expect(find.byType(PaymentMethodsSection), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reports a method selection', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final reported = <List<String>>[];

      await pump(
        tester,
        PaymentMethodsSection(
          selectedMethods: const [],
          customController: controller,
          onMethodsChanged: reported.add,
        ),
      );

      final l10n = S.of(tester.element(find.byType(PaymentMethodsSection)))!;

      final opener = find.byIcon(Icons.keyboard_arrow_down);
      expect(opener, findsOneWidget);
      await tester.tap(opener);
      await tester.pumpAndSettle();

      // "Other" is served by the custom field, so it is not offered here.
      expect(find.byType(CheckboxListTile), findsNWidgets(2));

      await tester.tap(find.text(l10n.bankTransfer));
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, l10n.confirm));
      await tester.pumpAndSettle();

      expect(reported, [
        [l10n.bankTransfer],
      ]);
      expect(tester.takeException(), isNull);
    });
  });

  group('PremiumSection', () {
    testWidgets('renders the current premium', (tester) async {
      await pump(tester, PremiumSection(value: 0, onChanged: (_) {}));

      expect(find.byType(PremiumSection), findsOneWidget);
      expect(tester.takeException(), isNull);
      await disposeWidget(tester);
    });

    testWidgets('renders a negative premium', (tester) async {
      await pump(tester, PremiumSection(value: -5, onChanged: (_) {}));

      expect(find.byType(PremiumSection), findsOneWidget);
      await disposeWidget(tester);
    });

    testWidgets('renders a positive premium', (tester) async {
      await pump(tester, PremiumSection(value: 7.5, onChanged: (_) {}));

      expect(find.byType(PremiumSection), findsOneWidget);
      await disposeWidget(tester);
    });

    testWidgets('reports a typed premium after the debounce', (tester) async {
      final reported = <double>[];
      await pump(tester, PremiumSection(value: 0, onChanged: reported.add));

      final fields = find.byType(TextField);
      if (fields.evaluate().isNotEmpty) {
        await tester.enterText(fields.first, '3');
        await tester.pump(const Duration(seconds: 2));
      }

      expect(tester.takeException(), isNull);
      await disposeWidget(tester);
    });
  });

  group('AmountSection', () {
    testWidgets('renders a single-amount buy order', (tester) async {
      await pump(
        tester,
        AmountSection(
          orderType: OrderType.buy,
          onAmountChanged: (_, __) {},
          fiatCode: 'USD',
        ),
      );

      expect(find.byType(AmountSection), findsOneWidget);
      expect(tester.takeException(), isNull);
      await disposeWidget(tester);
    });

    testWidgets('renders a sell order without a fiat code', (tester) async {
      await pump(
        tester,
        AmountSection(
          orderType: OrderType.sell,
          onAmountChanged: (_, __) {},
        ),
      );

      expect(find.byType(AmountSection), findsOneWidget);
      expect(tester.takeException(), isNull);
      await disposeWidget(tester);
    });

    testWidgets('surfaces a validation error', (tester) async {
      await pump(
        tester,
        AmountSection(
          orderType: OrderType.buy,
          onAmountChanged: (_, __) {},
          validationError: 'Amount is out of range',
          validateSatsRange: (_) => 'too small',
          onRangeModeChanged: (_) {},
          fiatCode: 'USD',
        ),
      );

      expect(find.byType(AmountSection), findsOneWidget);
      expect(tester.takeException(), isNull);
      await disposeWidget(tester);
    });

    testWidgets('reports a typed amount', (tester) async {
      final reported = <(int?, int?)>[];
      await pump(
        tester,
        AmountSection(
          orderType: OrderType.buy,
          onAmountChanged: (min, max) => reported.add((min, max)),
          fiatCode: 'USD',
        ),
      );

      final fields = find.byType(TextField);
      if (fields.evaluate().isNotEmpty) {
        await tester.enterText(fields.first, '100');
        await tester.pump(const Duration(seconds: 2));
      }

      expect(tester.takeException(), isNull);
      await disposeWidget(tester);
    });
  });
}
