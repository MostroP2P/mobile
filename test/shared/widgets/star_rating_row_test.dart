import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/shared/widgets/star_rating_row.dart';

/// The 5-star rating in every order card used to be a horizontal
/// `ListView.builder(shrinkWrap: true)` — a Scrollable + Viewport + Sliver
/// per card just to lay out five icons.
void main() {
  Future<void> pump(WidgetTester tester, double rating) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: StarRatingRow(rating: rating)),
        ),
      );

  testWidgets('renders five icons without any scrollable', (tester) async {
    await pump(tester, 3.5);

    expect(find.byType(Scrollable), findsNothing);
    expect(find.byIcon(Icons.star), findsNWidgets(3));
    expect(find.byIcon(Icons.star_half), findsOneWidget);
    expect(find.byIcon(Icons.star_border), findsOneWidget);
  });

  testWidgets('a fraction below .5 rounds down to border stars',
      (tester) async {
    await pump(tester, 2.4);

    expect(find.byIcon(Icons.star), findsNWidgets(2));
    expect(find.byIcon(Icons.star_half), findsNothing);
    expect(find.byIcon(Icons.star_border), findsNWidgets(3));
  });

  testWidgets('zero and full ratings render edge cases', (tester) async {
    await pump(tester, 0);
    expect(find.byIcon(Icons.star_border), findsNWidgets(5));

    await pump(tester, 5);
    expect(find.byIcon(Icons.star), findsNWidgets(5));
  });
}
