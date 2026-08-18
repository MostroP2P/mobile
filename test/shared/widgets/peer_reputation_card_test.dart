import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/user_info.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/widgets/order_cards.dart';

Future<void> pumpCard(
  WidgetTester tester, {
  required UserInfo reputation,
  required bool counterpartIsBuyer,
}) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      home: Scaffold(
        body: PeerReputationCard(
          reputation: reputation,
          counterpartIsBuyer: counterpartIsBuyer,
        ),
      ),
    ),
  );
}

void main() {
  const reputation = UserInfo(rating: 4.375, reviews: 4, operatingDays: 64);

  testWidgets('renders the buyer title and the three metrics', (tester) async {
    await pumpCard(tester, reputation: reputation, counterpartIsBuyer: true);

    expect(find.text("Buyer's Reputation"), findsOneWidget);
    expect(find.text('4.4'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('64'), findsOneWidget);
    expect(find.text('No reputation history yet'), findsNothing);
  });

  testWidgets('renders the seller title', (tester) async {
    await pumpCard(tester, reputation: reputation, counterpartIsBuyer: false);

    expect(find.text("Seller's Reputation"), findsOneWidget);
  });

  testWidgets('zeroed reputation renders as no history, not 0 stars',
      (tester) async {
    await pumpCard(
      tester,
      reputation: const UserInfo(rating: 0.0, reviews: 0, operatingDays: 0),
      counterpartIsBuyer: true,
    );

    expect(find.text('No reputation history yet'), findsOneWidget);
    expect(find.text('0.0'), findsNothing);
  });

  group('PeerReputationInline', () {
    Future<void> pumpInline(
      WidgetTester tester, {
      required UserInfo reputation,
      required bool counterpartIsBuyer,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: Scaffold(
            body: PeerReputationInline(
              reputation: reputation,
              counterpartIsBuyer: counterpartIsBuyer,
            ),
          ),
        ),
      );
    }

    testWidgets('renders the compact single-line summary', (tester) async {
      await pumpInline(
        tester,
        reputation: const UserInfo(rating: 2.5, reviews: 1, operatingDays: 4),
        counterpartIsBuyer: true,
      );

      expect(find.text("Buyer's Reputation"), findsOneWidget);
      expect(find.text('2.5 / 5 · 1 review · 4 days'), findsOneWidget);
    });

    testWidgets('pluralizes reviews and days', (tester) async {
      await pumpInline(
        tester,
        reputation: reputation,
        counterpartIsBuyer: false,
      );

      expect(find.text("Seller's Reputation"), findsOneWidget);
      expect(find.text('4.4 / 5 · 4 reviews · 64 days'), findsOneWidget);
    });

    testWidgets('zeroed reputation renders as no history', (tester) async {
      await pumpInline(
        tester,
        reputation: const UserInfo(rating: 0.0, reviews: 0, operatingDays: 0),
        counterpartIsBuyer: true,
      );

      expect(find.text('No reputation history yet'), findsOneWidget);
    });
  });
}
