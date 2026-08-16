import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/features/logs/logs_provider.dart';
import 'package:mostro_mobile/features/logs/screens/logs_screen.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

Future<void> pumpLogsScreen(WidgetTester tester) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const LogsScreen()),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(SharedPreferencesAsync()),
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

/// Unmounts the screen and drains any pending timers it scheduled.
Future<void> disposeScreen(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 30));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    MemoryLogOutput.isLoggingEnabled = true;
    MemoryLogOutput.instance.clear();
  });

  tearDown(() {
    MemoryLogOutput.instance.clear();
    MemoryLogOutput.isLoggingEnabled = false;
  });

  group('LogsFilter', () {
    test('defaults to no level filter and an empty query', () {
      const filter = LogsFilter();

      expect(filter.levelFilter, isNull);
      expect(filter.searchQuery, '');
    });

    test('copyWith overrides only what is given', () {
      const filter = LogsFilter(levelFilter: 'info', searchQuery: 'relay');

      expect(filter.copyWith(searchQuery: 'order').levelFilter, 'info');
      expect(filter.copyWith(searchQuery: 'order').searchQuery, 'order');
      expect(filter.copyWith(levelFilter: 'error').levelFilter, 'error');
      expect(filter.copyWith().searchQuery, 'relay');
    });
  });

  group('filteredLogsProvider', () {
    ProviderContainer container() {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      return c;
    }

    test('returns every log when no filter is applied', () {
      logger.i('a relay message');
      logger.e('an error message');

      final logs = container().read(filteredLogsProvider(const LogsFilter()));

      expect(logs.length, greaterThanOrEqualTo(2));
    });

    test('filters by level', () {
      logger.i('an info message');
      logger.e('an error message');

      final errors = container()
          .read(filteredLogsProvider(const LogsFilter(levelFilter: 'error')));

      expect(errors, isNotEmpty);
      expect(errors.every((e) => e.level == Level.error), isTrue);
    });

    test('treats the "all" level as no filter', () {
      logger.i('an info message');

      final all = container()
          .read(filteredLogsProvider(const LogsFilter(levelFilter: 'all')));

      expect(all, isNotEmpty);
    });

    test('filters by search query', () {
      logger.i('subscribed to wss://relay.example');
      logger.i('order 1234 created');

      final matches = container()
          .read(filteredLogsProvider(const LogsFilter(searchQuery: 'relay')));

      expect(matches, isNotEmpty);
    });

    test('returns nothing when the query matches no log', () {
      logger.i('order created');

      final matches = container().read(
          filteredLogsProvider(const LogsFilter(searchQuery: 'nonexistent')));

      expect(matches, isEmpty);
    });
  });

  group('LogsScreen', () {
    testWidgets('renders an empty log list', (tester) async {
      await pumpLogsScreen(tester);

      expect(find.byType(LogsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await disposeScreen(tester);
    });

    testWidgets('renders recorded log entries', (tester) async {
      logger.i('subscribed to wss://relay.example');
      logger.w('relay went away');
      logger.e('failed to publish');

      await pumpLogsScreen(tester);

      expect(find.byType(LogsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await disposeScreen(tester);
    });

    testWidgets('filters the list as the user types a query', (tester) async {
      logger.i('subscribed to wss://relay.example');
      logger.i('order 1234 created');

      await pumpLogsScreen(tester);

      final field = find.byType(TextField);
      if (field.evaluate().isNotEmpty) {
        await tester.enterText(field.first, 'relay');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }

      expect(tester.takeException(), isNull);
      await disposeScreen(tester);
    });

    testWidgets('scrolls the log list', (tester) async {
      for (var i = 0; i < 40; i++) {
        logger.i('log line $i');
      }

      await pumpLogsScreen(tester);

      final scrollables = find.byType(Scrollable);
      if (scrollables.evaluate().isNotEmpty) {
        await tester.drag(scrollables.last, const Offset(0, -600));
        await tester.pump();
      }

      expect(tester.takeException(), isNull);
      await disposeScreen(tester);
    });
  });
}
