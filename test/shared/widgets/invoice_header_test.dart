import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/user_info.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/widgets/invoice_header.dart';

Future<void> pumpHeader(
  WidgetTester tester, {
  required bool userIsSeller,
  UserInfo? reputation,
}) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      home: Scaffold(
        body: InvoiceHeader(
          userIsSeller: userIsSeller,
          sats: 550,
          fiatAmount: '235',
          fiatCode: 'CUP',
          orderId: '20a5d3c2-e69d-4f63-b57c-c97beffbd939',
          reputation: reputation,
        ),
      ),
    ),
  );
}

void main() {
  const reputation = UserInfo(rating: 2.5, reviews: 1, operatingDays: 4);

  testWidgets('seller flow: pay instruction and buyer reputation',
      (tester) async {
    await pumpHeader(tester, userIsSeller: true, reputation: reputation);

    expect(find.text('A buyer has taken your sell order.'), findsOneWidget);
    expect(
      find.text('If you want to continue with the exchange, pay this '
          'Lightning invoice for 550 sats, equivalent to 235 CUP.'),
      findsOneWidget,
    );
    expect(
      find.text('Order ID: 20a5d3c2-e69d-4f63-b57c-c97beffbd939',
          findRichText: true),
      findsOneWidget,
    );
    expect(find.text("Buyer's Reputation"), findsOneWidget);
    expect(find.text('2.5 / 5 · 1 review · 4 days'), findsOneWidget);
  });

  testWidgets('buyer flow: add instruction and seller reputation',
      (tester) async {
    await pumpHeader(tester, userIsSeller: false, reputation: reputation);

    expect(find.text('A seller has taken your buy order.'), findsOneWidget);
    expect(
      find.text('If you want to continue with the exchange, add a '
          'Lightning invoice for 550 sats, equivalent to 235 CUP.'),
      findsOneWidget,
    );
    expect(find.text("Seller's Reputation"), findsOneWidget);
  });

  testWidgets('omits the reputation block when none was received',
      (tester) async {
    await pumpHeader(tester, userIsSeller: true);

    expect(find.text('A buyer has taken your sell order.'), findsOneWidget);
    expect(find.text("Buyer's Reputation"), findsNothing);
    expect(find.text('No reputation history yet'), findsNothing);
  });

  testWidgets('every line shares one size and inherits the theme font',
      (tester) async {
    await pumpHeader(tester, userIsSeller: true, reputation: reputation);

    final texts = tester.widgetList<Text>(
      find.descendant(
        of: find.byType(InvoiceHeader),
        matching: find.byType(Text),
      ),
    );

    expect(texts, isNotEmpty);
    for (final text in texts) {
      expect(text.style?.fontSize, 16, reason: 'mixed text sizes: $text');
      // No hardcoded family: the theme font must come through
      expect(text.style?.fontFamily, isNull);
    }
    // The order id line must be a Text.rich: a bare RichText would bypass
    // DefaultTextStyle and render in a different font
    final richLine = texts.firstWhere((t) => t.textSpan != null);
    expect(richLine.textSpan!.toPlainText(), startsWith('Order ID: '));
  });

  testWidgets('every line is left aligned', (tester) async {
    await pumpHeader(tester, userIsSeller: true, reputation: reputation);

    final column = tester.widget<Column>(
      find
          .descendant(
            of: find.byType(InvoiceHeader),
            matching: find.byType(Column),
          )
          .first,
    );
    expect(column.crossAxisAlignment, CrossAxisAlignment.start);
  });
}
