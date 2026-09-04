import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/core/app.dart';
import 'package:mostro_mobile/core/deep_link_handler.dart';
import 'package:mostro_mobile/shared/providers/app_init_provider.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const _link = 'mostro:8927bb1d-da68-491e-b0e2-db0ed548d52c'
    '?relays=wss://relay.mostro.network';

const _otherLink = 'mostro:0f2c3d4e-5a6b-7c8d-9e0f-1a2b3c4d5e6f'
    '?relays=wss://relay.mostro.network';

const _appLinksChannel = MethodChannel('com.llfbandit.app_links/messages');

/// Stands in for [DeepLinkHandler] and records what the app hands over. Like
/// the real one it never throws: it reports whether it could attempt the link.
class _RecordingHandler implements DeepLinkHandler {
  final List<Uri> handled = [];
  final List<Uri> refused = [];
  int refusals = 0;

  @override
  void initialize(GoRouter router) {}

  @override
  Future<bool> handleInitialDeepLink(Uri uri, GoRouter router) async {
    if (refusals > 0) {
      refusals--;
      refused.add(uri);
      return false;
    }
    handled.add(uri);
    return true;
  }

  @override
  void dispose() {}
}

void main() {
  late Completer<String?> initialLink;
  late Completer<void> appInit;
  late _RecordingHandler handler;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    handler = _RecordingHandler();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_appLinksChannel, (call) async {
      if (call.method == 'getInitialLink') return initialLink.future;
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_appLinksChannel, null);
  });

  // The completers are created here so they belong to the test's async zone;
  // created in setUp they never complete for the widget under test.
  Future<void> pumpApp(WidgetTester tester, {bool initialized = false}) {
    initialLink = Completer<String?>();
    appInit = Completer<void>();
    if (initialized) appInit.complete();
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(SharedPreferencesAsync()),
          appInitializerProvider.overrideWith((ref) => appInit.future),
          deepLinkHandlerProvider.overrideWithValue(handler),
        ],
        child: const MostroApp(),
      ),
    );
  }

  group('deep link delivery', () {
    // Regression test for #670: the router is only created once initialization
    // resolves, so a link arriving first has to wait for it.
    testWidgets('waits for the router when the app is still starting up',
        (tester) async {
      await pumpApp(tester);

      initialLink.complete(_link);
      await tester.pump();
      expect(handler.handled, isEmpty);

      appInit.complete();
      await tester.pump();
      await tester.pump();

      expect(handler.handled, [Uri.parse(_link)]);
    });

    // A link arriving once the app has settled must not wait for a frame that
    // nobody is going to ask for.
    testWidgets('is delivered without a new frame when the app is running',
        (tester) async {
      await pumpApp(tester, initialized: true);
      await tester.pump();
      await tester.pump();

      initialLink.complete(_link);
      await tester.idle();

      expect(handler.handled, [Uri.parse(_link)]);
    });

    // The handler reports rather than throws when it could not attempt a link,
    // so the retry has to key on that.
    testWidgets('is handed over again when the app could not attempt it',
        (tester) async {
      handler.refusals = 1;
      await pumpApp(tester, initialized: true);
      await tester.pump();
      await tester.pump();

      initialLink.complete(_link);
      await tester.idle();
      expect(handler.refused, [Uri.parse(_link)]);
      expect(handler.handled, isEmpty);

      // The retry rides on the frame it asks for, not on an unrelated rebuild.
      await tester.pump();
      await tester.idle();

      expect(handler.handled, [Uri.parse(_link)]);
    });

    testWidgets('is dropped once the retries run out', (tester) async {
      handler.refusals = 100;
      await pumpApp(tester, initialized: true);
      await tester.pump();
      await tester.pump();

      initialLink.complete(_link);
      await tester.idle();
      for (var i = 0; i < 20; i++) {
        await tester.pump();
        await tester.idle();
      }

      expect(handler.handled, isEmpty);
      expect(handler.refused.length, lessThanOrEqualTo(11));
    });

    testWidgets('the newest link wins when two arrive before the router',
        (tester) async {
      await pumpApp(tester);
      initialLink.complete(null);
      await tester.pump();

      await tester.binding.handlePushRoute(_link);
      await tester.binding.handlePushRoute(_otherLink);
      await tester.pump();
      expect(handler.handled, isEmpty);

      appInit.complete();
      await tester.pump();
      await tester.pump();

      expect(handler.handled, [Uri.parse(_otherLink)]);
    });

    // createRouter discards the platform default; app_links is not the only
    // way that link can be recovered.
    testWidgets('falls back to the platform default when app_links has none',
        (tester) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue = _link;
      addTearDown(
          tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);

      await pumpApp(tester, initialized: true);
      initialLink.complete(null);
      await tester.pump();
      await tester.idle();
      await tester.pump();

      expect(handler.handled, [Uri.parse(_link)]);
    });

    // The interceptor keeps custom schemes away from go_router; before, it
    // dropped them when the router did not exist yet.
    testWidgets('an intercepted link survives until the router exists',
        (tester) async {
      await pumpApp(tester);
      initialLink.complete(null);
      await tester.pump();

      await tester.binding.handlePushRoute(_link);
      await tester.pump();
      expect(handler.handled, isEmpty);

      appInit.complete();
      await tester.pump();
      await tester.pump();

      expect(handler.handled, [Uri.parse(_link)]);
    });
  });
}
