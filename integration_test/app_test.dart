import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mostro_mobile/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Create and send a new sell order', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Navigate to Create Order Screen
    final createOrderButton = find.byKey(Key('createOrderButton'));
    await tester.tap(createOrderButton);
    await tester.pumpAndSettle();

    // Input order details
    await tester.enterText(find.byKey(Key('fiatAmountField')), '100');
    await tester.tap(find.byKey(Key('submitOrderButton')));
    await tester.pumpAndSettle();

    // Verify that order confirmation appears on UI
    final confirmationMessage = find.text('Order Created');
    expect(confirmationMessage, findsOneWidget);
  });
}
