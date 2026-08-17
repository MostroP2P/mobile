import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/currency.dart';
import 'package:mostro_mobile/features/home/providers/home_order_providers.dart';
import 'package:mostro_mobile/features/order/providers/payment_methods_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/providers/exchange_service_provider.dart';
import 'package:mostro_mobile/shared/widgets/order_filter.dart';

Currency _currency(String code, String emoji, String name) => Currency(
      symbol: code,
      name: name,
      symbolNative: code,
      code: code,
      emoji: emoji,
      decimalDigits: 2,
      namePlural: name,
      price: true,
    );

final _currencies = <String, Currency>{
  'USD': _currency('USD', '🇺🇸', 'US Dollar'),
  'EUR': _currency('EUR', '🇪🇺', 'Euro'),
  'ARS': _currency('ARS', '🇦🇷', 'Argentine Peso'),
};

const _paymentMethods = <String, dynamic>{
  'USD': ['Bank Transfer', 'Cash in person', 'Other'],
  'ARS': ['Mercado Pago', 'Cash in person', 'Other'],
  'EUR': ['SEPA', 'Revolut'],
};

late ProviderContainer _container;

Future<void> pumpFilter(
  WidgetTester tester, {
  Map<String, dynamic>? paymentMethods,
  List<Override> extra = const [],
  Locale? locale,
}) async {
  _container = ProviderContainer(
    overrides: [
      currencyCodesProvider.overrideWith((ref) async => _currencies),
      paymentMethodsDataProvider
          .overrideWith((ref) async => paymentMethods ?? _paymentMethods),
      ...extra,
    ],
  );
  addTearDown(_container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: _container,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: const Scaffold(body: Center(child: OrderFilter())),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// The localizations the panel itself resolved, so tests target the same
/// labels the user sees instead of widget ordering.
S _l10n(WidgetTester tester) => S.of(tester.element(find.byType(OrderFilter)))!;

/// Unmounts the widget and drains any pending timers it scheduled.
Future<void> disposeWidget(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  group('MultiSelectAutocomplete', () {
    Future<void> pumpAutocomplete(
      WidgetTester tester, {
      List<String> selected = const [],
      required ValueChanged<List<String>> onChanged,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: Scaffold(
            body: MultiSelectAutocomplete(
              label: 'Currencies',
              options: const ['USD', 'EUR', 'ARS'],
              selectedValues: selected,
              onChanged: onChanged,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders its label and current selection', (tester) async {
      await pumpAutocomplete(tester,
          selected: const ['USD'], onChanged: (_) {});

      expect(
          find.textContaining('Currencies', findRichText: true), findsWidgets);
      expect(find.textContaining('USD', findRichText: true), findsWidgets);
    });

    testWidgets('suggests matching options as the user types', (tester) async {
      await pumpAutocomplete(tester, onChanged: (_) {});

      await tester.enterText(find.byType(TextField).first, 'us');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Only USD matches "us"; the other two options stay hidden.
      final options = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Text),
      );
      expect(options, findsOneWidget);
      expect(tester.widget<Text>(options).data, 'USD');
      expect(tester.takeException(), isNull);
    });

    testWidgets('reports a new selection', (tester) async {
      final reported = <List<String>>[];
      await pumpAutocomplete(tester, onChanged: reported.add);

      await tester.enterText(find.byType(TextField).first, 'EUR');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final option = find.descendant(
        of: find.byType(ListView),
        matching: find.text('EUR'),
      );
      expect(option, findsOneWidget);

      await tester.tap(option);
      await tester.pump();

      expect(reported, [
        ['EUR'],
      ]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('removes a selected value when its chip is dismissed',
        (tester) async {
      final reported = <List<String>>[];
      await pumpAutocomplete(
        tester,
        selected: const ['USD', 'EUR'],
        onChanged: reported.add,
      );

      // One dismiss affordance per selected value, in selection order.
      final dismissIcons = find.byIcon(Icons.close);
      expect(dismissIcons, findsNWidgets(2));

      await tester.tap(dismissIcons.first);
      await tester.pump();

      expect(reported, [
        ['EUR'],
      ]);
      expect(tester.takeException(), isNull);
    });
  });

  group('OrderFilter', () {
    testWidgets('renders with the default filter values', (tester) async {
      await pumpFilter(tester);

      expect(find.byType(OrderFilter), findsOneWidget);
      expect(tester.takeException(), isNull);
      await disposeWidget(tester);
    });

    // Regression test for the horizontal RenderFlex overflow the range rows
    // used to produce: both ends of every range row must lay out inside the
    // panel without the framework reporting an overflow.
    testWidgets('lays out its range rows without overflowing', (tester) async {
      await pumpFilter(tester);
      final l10n = _l10n(tester);

      final panelWidth = tester.getSize(find.byType(OrderFilter)).width;
      final labels = <String>[
        '${l10n.discount}: -10%',
        '${l10n.premium}: 10%',
        '${l10n.min}: 0',
        '${l10n.max}: 5',
      ];
      for (final label in labels) {
        final finder = find.text(label);
        expect(finder, findsOneWidget, reason: 'missing range label "$label"');
        expect(tester.getSize(finder).width, lessThanOrEqualTo(panelWidth));
      }

      expect(tester.takeException(), isNull);
      await disposeWidget(tester);
    });

    // "Giorni" is the longest translation of the days label, so this is the
    // worst case for the two fixed-width boxes on the right of the days row.
    testWidgets('keeps the days labels on one line in every locale',
        (tester) async {
      await pumpFilter(tester, locale: const Locale('it'));
      final l10n = _l10n(tester);

      final maxLabel = find.text('${l10n.days}: 20');
      expect(maxLabel, findsOneWidget);

      final lineHeight = tester.getSize(find.text('${l10n.days}: 0')).height;
      expect(
        tester.getSize(maxLabel).height,
        lineHeight,
        reason: 'the max-days label wrapped instead of staying on one line',
      );

      // The label used to be pinned to a 72 px box to line up with the days
      // input; shrink-wrapping must keep that right edge.
      expect(
        tester.getBottomRight(maxLabel).dx,
        tester.getBottomRight(find.byKey(const Key('minDaysField'))).dx,
      );

      expect(tester.takeException(), isNull);
      await disposeWidget(tester);
    });

    testWidgets('seeds itself from the current filter providers',
        (tester) async {
      await pumpFilter(
        tester,
        extra: [
          currencyFilterProvider.overrideWith((ref) => ['USD']),
          paymentMethodFilterProvider.overrideWith((ref) => ['Bank Transfer']),
          ratingFilterProvider.overrideWith((ref) => (min: 2.0, max: 4.0)),
          premiumRangeFilterProvider
              .overrideWith((ref) => (min: -5.0, max: 5.0)),
          minDaysFilterProvider.overrideWith((ref) => 7),
        ],
      );
      final l10n = _l10n(tester);

      expect(find.text('${l10n.discount}: -5%'), findsOneWidget);
      expect(find.text('${l10n.premium}: 5%'), findsOneWidget);
      expect(find.text('${l10n.min}: 2'), findsOneWidget);
      expect(find.text('${l10n.max}: 4'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('minDaysField')))
            .controller!
            .text,
        '7',
      );
      expect(tester.takeException(), isNull);
      await disposeWidget(tester);
    });

    testWidgets('does not offer "Other" as a payment method filter',
        (tester) async {
      await pumpFilter(tester);

      expect(find.text('Other'), findsNothing);
      expect(tester.takeException(), isNull);
      await disposeWidget(tester);
    });

    testWidgets('tolerates a malformed payment method catalogue',
        (tester) async {
      await pumpFilter(tester, paymentMethods: const {
        'USD': 'not-a-list',
        'EUR': ['SEPA'],
      });

      expect(find.byType(OrderFilter), findsOneWidget);
      expect(tester.takeException(), isNull);
      await disposeWidget(tester);
    });

    testWidgets('scrolls through the whole filter panel', (tester) async {
      await pumpFilter(tester);

      final scrollable = find.byType(SingleChildScrollView);
      expect(scrollable, findsOneWidget);
      // The panel's own viewport, not the ones nested inside its text fields.
      final panelScrollable = tester.state<ScrollableState>(
        find
            .descendant(of: scrollable, matching: find.byType(Scrollable))
            .first,
      );
      expect(panelScrollable.position.pixels, 0);

      await tester.drag(scrollable, const Offset(0, -800));
      await tester.pump();

      expect(panelScrollable.position.pixels, greaterThan(0));
      expect(tester.takeException(), isNull);
      await disposeWidget(tester);
    });

    testWidgets('accepts a minimum-days value', (tester) async {
      await pumpFilter(tester);

      final daysField = find.byKey(const Key('minDaysField'));
      expect(daysField, findsOneWidget);

      await tester.enterText(daysField, '15');
      await tester.pump();
      final l10n = _l10n(tester);

      // The right-hand label tracks the typed value once it passes 20.
      expect(find.text('${l10n.days}: 20'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await disposeWidget(tester);
    });

    testWidgets('resets every filter provider when cleared', (tester) async {
      await pumpFilter(
        tester,
        extra: [
          currencyFilterProvider.overrideWith((ref) => ['USD']),
          paymentMethodFilterProvider.overrideWith((ref) => ['Bank Transfer']),
          ratingFilterProvider.overrideWith((ref) => (min: 2.0, max: 4.0)),
          premiumRangeFilterProvider
              .overrideWith((ref) => (min: -5.0, max: 5.0)),
          minDaysFilterProvider.overrideWith((ref) => 7),
        ],
      );

      final clear = find.widgetWithText(
        OutlinedButton,
        _l10n(tester).clear.toUpperCase(),
      );
      expect(clear, findsOneWidget);

      await tester.tap(clear);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(_container.read(currencyFilterProvider), isEmpty);
      expect(_container.read(paymentMethodFilterProvider), isEmpty);
      expect(_container.read(ratingFilterProvider), (min: 0.0, max: 5.0));
      expect(
          _container.read(premiumRangeFilterProvider), (min: -10.0, max: 10.0));
      expect(_container.read(minDaysFilterProvider), 0);
      expect(tester.takeException(), isNull);
      await disposeWidget(tester);
    });

    testWidgets('applies the selected filters to the providers',
        (tester) async {
      await pumpFilter(
        tester,
        extra: [
          currencyFilterProvider.overrideWith((ref) => ['USD']),
          paymentMethodFilterProvider.overrideWith((ref) => ['Bank Transfer']),
          ratingFilterProvider.overrideWith((ref) => (min: 2.0, max: 4.0)),
          premiumRangeFilterProvider
              .overrideWith((ref) => (min: -5.0, max: 5.0)),
          minDaysFilterProvider.overrideWith((ref) => 7),
        ],
      );

      // Change one value through the UI so the assertion cannot pass on the
      // seeded provider state alone.
      await tester.enterText(find.byKey(const Key('minDaysField')), '15');
      await tester.pump();

      final apply = find.widgetWithText(
        ElevatedButton,
        _l10n(tester).apply.toUpperCase(),
      );
      expect(apply, findsOneWidget);

      await tester.tap(apply);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(_container.read(minDaysFilterProvider), 15);
      expect(_container.read(currencyFilterProvider), ['USD']);
      expect(_container.read(paymentMethodFilterProvider), ['Bank Transfer']);
      expect(_container.read(ratingFilterProvider), (min: 2.0, max: 4.0));
      expect(
          _container.read(premiumRangeFilterProvider), (min: -5.0, max: 5.0));
      expect(tester.takeException(), isNull);
      await disposeWidget(tester);
    });
  });
}
