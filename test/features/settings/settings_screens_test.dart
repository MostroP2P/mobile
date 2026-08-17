import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/data/models/currency.dart';
import 'package:mostro_mobile/features/settings/notification_settings_screen.dart';
import 'package:mostro_mobile/features/settings/settings_screen.dart';
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
  'EUR': Currency(
    symbol: '€',
    name: 'Euro',
    symbolNative: '€',
    code: 'EUR',
    emoji: '🇪🇺',
    decimalDigits: 2,
    namePlural: 'euros',
    price: true,
  ),
};

/// Pumps [screen] behind a router with an in-memory SharedPreferences, so
/// `settingsProvider` and `mostroNodesProvider` build normally.
Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => screen),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const Scaffold(body: Text('settings')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(SharedPreferencesAsync()),
        currencyCodesProvider.overrideWith((ref) async => _currencies),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Unmounts the screen and drains any pending timers it scheduled, so the
/// test binding's "timer still pending" invariant holds.
Future<void> disposeScreen(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 30));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('SettingsScreen', () {
    testWidgets('renders without throwing', (tester) async {
      await pumpScreen(tester, const SettingsScreen());

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await disposeScreen(tester);
    });

    testWidgets('scrolls through the full settings list', (tester) async {
      await pumpScreen(tester, const SettingsScreen());

      final scrollables = find.byType(Scrollable);
      if (scrollables.evaluate().isNotEmpty) {
        await tester.drag(scrollables.first, const Offset(0, -2000));
        await tester.pump();
      }

      expect(tester.takeException(), isNull);
      await disposeScreen(tester);
    });

    testWidgets('taps through the tiles it renders', (tester) async {
      await pumpScreen(tester, const SettingsScreen());

      final tiles = find.byType(ListTile);
      if (tiles.evaluate().isNotEmpty) {
        await tester.tap(tiles.first, warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(tester.takeException(), isNull);
      await disposeScreen(tester);
    });
  });

  group('NotificationSettingsScreen', () {
    testWidgets('renders without throwing', (tester) async {
      await pumpScreen(tester, const NotificationSettingsScreen());

      expect(find.byType(NotificationSettingsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await disposeScreen(tester);
    });

    testWidgets('toggles every switch it renders', (tester) async {
      await pumpScreen(tester, const NotificationSettingsScreen());

      final count = find.byType(Switch).evaluate().length;
      for (var i = 0; i < count; i++) {
        await tester.tap(find.byType(Switch).at(i), warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(tester.takeException(), isNull);
      await disposeScreen(tester);
    });
  });
}
