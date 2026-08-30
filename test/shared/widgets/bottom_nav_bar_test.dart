import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/widgets/bottom_nav_bar.dart';

/// The three bottom tabs are root destinations. Switching between them must
/// replace the current page, not push on top of it: pushed tabs stay mounted
/// (`maintainState`) and keep rebuilding on every order/chat event, so after
/// N taps N live screens were doing the work of one.
void main() {
  late GoRouter router;

  Widget tab(String name) => Scaffold(
        body: Center(child: Text(name)),
        bottomNavigationBar: const BottomNavBar(),
      );

  Future<void> pumpApp(WidgetTester tester) async {
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => tab('home')),
        GoRoute(path: '/order_book', builder: (_, __) => tab('trades')),
        GoRoute(path: '/chat_list', builder: (_, __) => tab('chats')),
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
    await tester.pumpAndSettle();
  }

  Future<void> tapTab(WidgetTester tester, IconData icon) async {
    await tester.tap(find.byIcon(icon));
    await tester.pumpAndSettle();
  }

  testWidgets('switching tabs replaces the root page instead of stacking',
      (tester) async {
    // Arrange
    await pumpApp(tester);
    expect(router.canPop(), isFalse);

    // Act
    await tapTab(tester, LucideIcons.zap);
    expect(find.text('trades'), findsOneWidget);
    await tapTab(tester, LucideIcons.messageSquare);
    expect(find.text('chats'), findsOneWidget);
    await tapTab(tester, LucideIcons.book);

    // Assert
    expect(find.text('home'), findsOneWidget);
    expect(router.state.uri.toString(), '/');
    expect(router.canPop(), isFalse,
        reason: 'tab navigation must not leave previous tabs on the stack');
    expect(find.text('trades', skipOffstage: false), findsNothing,
        reason: 'a replaced tab must be unmounted, not kept offstage');
  });

  testWidgets('tapping the active tab is a no-op', (tester) async {
    await pumpApp(tester);

    await tapTab(tester, LucideIcons.book);

    expect(router.state.uri.toString(), '/');
    expect(router.canPop(), isFalse);
  });
}
