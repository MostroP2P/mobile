import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/core/app_routes.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const _mostroLink =
    'mostro:8927bb1d-da68-491e-b0e2-db0ed548d52c?relays=wss://relay.mostro.network';

/// Holds a single router for the test, so a rebuild cannot make another one.
class _RouterHost extends ConsumerStatefulWidget {
  const _RouterHost();

  @override
  ConsumerState<_RouterHost> createState() => _RouterHostState();
}

class _RouterHostState extends ConsumerState<_RouterHost> {
  late final GoRouter router = createRouter(ref);

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Builds the app's real router inside a scope that can resolve it, and hands
/// it back without mounting any screen.
Future<GoRouter> buildRouter(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(SharedPreferencesAsync()),
      ],
      child: const _RouterHost(),
    ),
  );
  final router =
      tester.state<_RouterHostState>(find.byType(_RouterHost)).router;
  addTearDown(router.dispose);
  return router;
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('createRouter initial location', () {
    // Regression test for #670: go_router preferred the cold-start deep link
    // over initialLocation and asserted while matching it.
    testWidgets('ignores a custom scheme handed over by the platform',
        (tester) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue = _mostroLink;
      addTearDown(
          tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);

      final router = await buildRouter(tester);

      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('starts at the root on an ordinary launch', (tester) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue = '/';
      addTearDown(
          tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);

      final router = await buildRouter(tester);

      expect(router.routeInformationProvider.value.uri.toString(), '/');
      expect(tester.takeException(), isNull);
    });

    // On web the platform default is a real location and must still win.
    testWidgets('honours a real location handed over by the platform',
        (tester) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue = '/settings';
      addTearDown(
          tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);

      final router = await buildRouter(tester);

      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/settings',
      );
      expect(tester.takeException(), isNull);
    });
  });
}
