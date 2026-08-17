import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/mostro/widgets/trusted_badge.dart';
import 'package:mostro_mobile/features/notifications/widgets/detail_row.dart';
import 'package:mostro_mobile/features/order/widgets/fixed_switch_widget.dart';
import 'package:mostro_mobile/features/rate/star_rating.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/widgets/custom_button.dart';
import 'package:mostro_mobile/shared/widgets/custom_card.dart';
import 'package:mostro_mobile/shared/widgets/custom_elevated_button.dart';
import 'package:mostro_mobile/shared/widgets/mostro_switch.dart';

/// Wraps [child] in a MaterialApp with the app's localization delegates so
/// widgets that call `S.of(context)` can be pumped in isolation.
Widget host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  group('CustomButton', () {
    testWidgets('renders its label and fires onPressed when enabled',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(CustomButton(
        text: 'Continue',
        onPressed: () => taps++,
      )));

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(find.text('Continue'), findsOneWidget);
      expect(taps, 1);
    });

    testWidgets('disables the underlying button when isEnabled is false',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(CustomButton(
        text: 'Continue',
        onPressed: () => taps++,
        isEnabled: false,
      )));

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(button.onPressed, isNull);
      expect(taps, 0);
    });

    testWidgets('honours the configured width and minimum font size',
        (tester) async {
      await tester.pumpWidget(host(CustomButton(
        text: 'Continue',
        onPressed: () {},
        width: 320,
        minFontSize: 9,
      )));

      final sizedBox = tester.widget<SizedBox>(
        find
            .ancestor(
              of: find.byType(ElevatedButton),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      final label =
          tester.widget<AutoSizeText>(find.byType(AutoSizeText).first);

      expect(sizedBox.width, 320);
      expect(label.minFontSize, 9);
      expect(label.maxLines, 1);
    });
  });

  group('CustomElevatedButton', () {
    testWidgets('renders its label and fires onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(CustomElevatedButton(
        text: 'Submit',
        onPressed: () => taps++,
      )));

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(find.text('Submit'), findsOneWidget);
      expect(taps, 1);
    });

    testWidgets('stays unconstrained when no width is given', (tester) async {
      await tester.pumpWidget(host(CustomElevatedButton(
        text: 'Submit',
        onPressed: () {},
      )));

      expect(
        find.ancestor(
          of: find.byType(ElevatedButton),
          matching: find.byType(SizedBox),
        ),
        findsNothing,
      );
    });

    testWidgets('wraps itself in a SizedBox when a width is given',
        (tester) async {
      await tester.pumpWidget(host(CustomElevatedButton(
        text: 'Submit',
        onPressed: () {},
        width: 150,
      )));

      final sizedBox = tester.widget<SizedBox>(
        find
            .ancestor(
              of: find.byType(ElevatedButton),
              matching: find.byType(SizedBox),
            )
            .first,
      );

      expect(sizedBox.width, 150);
    });

    testWidgets('applies the supplied text style', (tester) async {
      const style = TextStyle(fontSize: 42, color: Colors.red);
      await tester.pumpWidget(host(CustomElevatedButton(
        text: 'Submit',
        onPressed: () {},
        textStyle: style,
        padding: const EdgeInsets.all(4),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      )));

      final label = tester.widget<AutoSizeText>(find.byType(AutoSizeText));

      expect(label.style, style);
    });
  });

  group('CustomCard', () {
    testWidgets('renders its child', (tester) async {
      await tester.pumpWidget(
        host(const CustomCard(child: Text('card body'))),
      );

      expect(find.text('card body'), findsOneWidget);
    });

    testWidgets('falls back to the dark theme colour', (tester) async {
      await tester.pumpWidget(
        host(const CustomCard(child: SizedBox.shrink())),
      );

      expect(tester.widget<Card>(find.byType(Card)).color, AppTheme.dark1);
    });

    testWidgets('honours explicit colour, margin, padding and border',
        (tester) async {
      await tester.pumpWidget(host(const CustomCard(
        color: Colors.purple,
        margin: EdgeInsets.all(6),
        padding: EdgeInsets.all(10),
        borderSide: BorderSide(color: Colors.orange),
        child: SizedBox.shrink(),
      )));

      final card = tester.widget<Card>(find.byType(Card));
      final padding = tester.widget<Padding>(
        find
            .descendant(of: find.byType(Card), matching: find.byType(Padding))
            .last,
      );

      expect(card.color, Colors.purple);
      expect(card.margin, const EdgeInsets.all(6));
      expect(padding.padding, const EdgeInsets.all(10));
      expect(
        (card.shape as RoundedRectangleBorder).side.color,
        Colors.orange,
      );
    });
  });

  group('MostroSwitch', () {
    testWidgets('reports the new value when toggled', (tester) async {
      bool? changed;
      await tester.pumpWidget(host(MostroSwitch(
        value: false,
        onChanged: (v) => changed = v,
      )));

      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(changed, isTrue);
    });

    testWidgets('is inert when onChanged is null', (tester) async {
      await tester.pumpWidget(host(const MostroSwitch(value: true)));

      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    });

    testWidgets('uses the brand colours for the selected state',
        (tester) async {
      await tester
          .pumpWidget(host(MostroSwitch(value: true, onChanged: (_) {})));

      final widget = tester.widget<Switch>(find.byType(Switch));

      expect(widget.thumbColor!.resolve({WidgetState.selected}),
          AppTheme.textPrimary);
      expect(
          widget.thumbColor!.resolve(<WidgetState>{}), AppTheme.textSecondary);
      expect(widget.trackColor!.resolve({WidgetState.selected}),
          AppTheme.mostroGreen);
      expect(widget.trackColor!.resolve(<WidgetState>{}),
          AppTheme.backgroundInactive);
      expect(widget.trackOutlineColor!.resolve(<WidgetState>{}),
          Colors.transparent);
    });
  });

  group('StarRating', () {
    testWidgets('starts with every star empty', (tester) async {
      await tester.pumpWidget(host(StarRating(onRatingChanged: (_) {})));

      expect(find.byIcon(Icons.star), findsNothing);
      expect(find.byIcon(Icons.star_border), findsNWidgets(5));
    });

    testWidgets('fills stars up to the initial rating', (tester) async {
      await tester.pumpWidget(host(StarRating(
        initialRating: 3,
        onRatingChanged: (_) {},
      )));

      expect(find.byIcon(Icons.star), findsNWidgets(3));
      expect(find.byIcon(Icons.star_border), findsNWidgets(2));
    });

    testWidgets('reports the 1-based rating when a star is tapped',
        (tester) async {
      final reported = <int>[];
      await tester.pumpWidget(host(StarRating(onRatingChanged: reported.add)));

      await tester.tap(find.byType(GestureDetector).at(3));
      await tester.pump();

      expect(reported, [4]);
      expect(find.byIcon(Icons.star), findsNWidgets(4));
    });

    testWidgets('colours filled stars with the brand green', (tester) async {
      await tester.pumpWidget(host(StarRating(
        initialRating: 1,
        onRatingChanged: (_) {},
      )));

      expect(tester.widget<Icon>(find.byIcon(Icons.star)).color,
          AppTheme.mostroGreen);
      expect(tester.widget<Icon>(find.byIcon(Icons.star_border).first).color,
          AppTheme.grey2);
    });
  });

  group('FixedSwitch', () {
    testWidgets('starts on "Fixed" and switches to "Market"', (tester) async {
      final reported = <bool>[];
      await tester.pumpWidget(host(FixedSwitch(onChanged: reported.add)));
      expect(find.text('Fixed'), findsOneWidget);

      await tester.tap(find.byKey(const Key('fixedSwitch')));
      await tester.pump();

      expect(reported, [true]);
      expect(find.text('Market'), findsOneWidget);
      expect(find.text('Fixed'), findsNothing);
    });

    testWidgets('honours the initial value', (tester) async {
      await tester.pumpWidget(host(FixedSwitch(
        initialValue: true,
        onChanged: (_) {},
      )));

      expect(find.text('Market'), findsOneWidget);
      expect(tester.widget<Switch>(find.byKey(const Key('fixedSwitch'))).value,
          isTrue);
    });
  });

  group('DetailRow', () {
    testWidgets('renders the label with a colon and the value', (tester) async {
      await tester.pumpWidget(host(const DetailRow(
        label: 'Order',
        value: 'a plain value',
        icon: HeroIcons.hashtag,
      )));

      expect(find.text('Order:'), findsOneWidget);
      expect(find.text('a plain value'), findsOneWidget);
      expect(find.byType(HeroIcon), findsOneWidget);
    });

    testWidgets('uses a proportional font for ordinary values', (tester) async {
      await tester.pumpWidget(host(const DetailRow(
        label: 'Note',
        value: 'hello world',
        icon: HeroIcons.hashtag,
      )));

      final value = tester.widget<Text>(find.text('hello world'));

      expect(value.style?.fontFamily, isNot('monospace'));
    });

    testWidgets('uses a monospace font for identifier-like values',
        (tester) async {
      const identifiers = [
        'npub1abcdef',
        'order #1234',
        'bc1qexampleaddress',
        'deadbeef1234',
      ];

      for (final identifier in identifiers) {
        await tester.pumpWidget(host(DetailRow(
          label: 'Id',
          value: identifier,
          icon: HeroIcons.hashtag,
        )));

        expect(
          tester.widget<Text>(find.text(identifier)).style?.fontFamily,
          'monospace',
          reason: '$identifier should render monospaced',
        );
      }
    });
  });

  group('TrustedBadge', () {
    testWidgets('renders the localized trusted label', (tester) async {
      await tester.pumpWidget(host(const TrustedBadge()));
      await tester.pumpAndSettle();

      expect(find.byType(TrustedBadge), findsOneWidget);
      expect(find.byType(Text), findsOneWidget);
      expect(tester.widget<Text>(find.byType(Text)).data, isNotEmpty);
    });
  });
}
