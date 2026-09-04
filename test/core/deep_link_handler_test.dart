import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/core/deep_link_handler.dart';

const _link = 'mostro:8927bb1d-da68-491e-b0e2-db0ed548d52c'
    '?relays=wss://relay.mostro.network';

/// A router that was never mounted, so it has no navigator to open a link with.
GoRouter unmountedRouter() => GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const Placeholder()),
      ],
    );

void main() {
  late ProviderContainer container;
  late GoRouter router;

  setUp(() {
    container = ProviderContainer();
    router = unmountedRouter();
  });

  tearDown(() {
    router.dispose();
    container.dispose();
  });

  group('handleInitialDeepLink reports what it could do', () {
    test('says no when there is no navigator to open the link with', () async {
      final handler = container.read(deepLinkHandlerProvider);

      expect(await handler.handleInitialDeepLink(Uri.parse(_link), router),
          isFalse);
    });

    test('says yes for a scheme it answers with a message', () async {
      final handler = container.read(deepLinkHandlerProvider);

      final uri = Uri.parse('lightning:lnbc1');

      expect(await handler.handleInitialDeepLink(uri, router), isTrue);
    });
  });
}
