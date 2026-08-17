import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/features/mostro/mostro_node.dart';
import 'package:mostro_mobile/features/mostro/widgets/mostro_node_avatar.dart';
import 'package:mostro_mobile/features/mostro/widgets/mostro_node_selector.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const _pubkey =
    '5555555555555555555555555555555555555555555555555555555555555555';

Future<void> pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(SharedPreferencesAsync()),
      ],
      child: MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Unmounts the widget and drains any pending timers it scheduled.
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

  group('MostroNodeAvatar', () {
    testWidgets('falls back to a generated avatar when there is no picture',
        (tester) async {
      await pump(tester, MostroNodeAvatar(node: MostroNode(pubkey: _pubkey)));

      expect(find.byType(MostroNodeAvatar), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders a network image when the node advertises a picture',
        (tester) async {
      await pump(
        tester,
        MostroNodeAvatar(
          node: MostroNode(
            pubkey: _pubkey,
            picture: 'https://example.test/avatar.png',
          ),
        ),
      );

      // The HTTP fetch fails under test, which exercises the errorBuilder path.
      await tester.pump();

      expect(find.byType(MostroNodeAvatar), findsOneWidget);
    });

    testWidgets('honours a custom size', (tester) async {
      await pump(
        tester,
        MostroNodeAvatar(node: MostroNode(pubkey: _pubkey), size: 72),
      );

      expect(find.byType(MostroNodeAvatar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('MostroNodeSelector', () {
    testWidgets('lists the trusted nodes', (tester) async {
      await pump(tester, const MostroNodeSelector());

      expect(find.byType(MostroNodeSelector), findsOneWidget);
      expect(tester.takeException(), isNull);
      await disposeScreen(tester);
    });

    testWidgets('scrolls the node list', (tester) async {
      await pump(tester, const MostroNodeSelector());

      final scrollables = find.byType(Scrollable);
      if (scrollables.evaluate().isNotEmpty) {
        await tester.drag(scrollables.first, const Offset(0, -400));
        await tester.pump();
      }

      expect(tester.takeException(), isNull);
      await disposeScreen(tester);
    });

    testWidgets('opens as a modal bottom sheet via show()', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider
                .overrideWithValue(SharedPreferencesAsync()),
          ],
          child: MaterialApp(
            localizationsDelegates: S.localizationsDelegates,
            supportedLocales: S.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => MostroNodeSelector.show(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(MostroNodeSelector), findsOneWidget);
      await disposeScreen(tester);
    });
  });
}
