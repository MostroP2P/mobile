import 'dart:async';

import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/model/request/request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/data/repositories/open_orders_repository.dart';
import 'package:mostro_mobile/features/settings/settings.dart';

import '../../mocks.mocks.dart';

const _nodePubkey =
    '0000000000000000000000000000000000000000000000000000000000000001';

Settings _settings() => Settings(
      relays: const ['wss://relay.example'],
      fullPrivacyMode: false,
      mostroPublicKey: _nodePubkey,
    );

void main() {
  group('OpenOrdersRepository subscriptions', () {
    late MockNostrService nostrService;
    late List<NostrRequest> requests;
    late List<StreamController<NostrEvent>> controllers;

    setUp(() {
      nostrService = MockNostrService();
      requests = [];
      controllers = [];

      when(nostrService.isInitialized).thenReturn(true);
      when(nostrService.subscribeToEvents(any)).thenAnswer((invocation) {
        requests.add(invocation.positionalArguments.first as NostrRequest);
        final controller = StreamController<NostrEvent>.broadcast();
        controllers.add(controller);
        return controller.stream;
      });
    });

    tearDown(() {
      for (final controller in controllers) {
        controller.close();
      }
    });

    test('asks for the node info event on its own request, and first', () {
      final repository = OpenOrdersRepository(nostrService, _settings());
      addTearDown(repository.dispose);

      expect(requests, hasLength(2));

      // The info event is what the settlement checks pin their fee rate from,
      // and it is pinned at the moment the user commits. Behind the order
      // backlog it can land after the take, which leaves the trade reporting a
      // settlement it could not verify for as long as it lives.
      final info = requests.first.filters.single;
      expect(info.kinds, [infoEventKind]);
      expect(info.authors, [_nodePubkey]);
      expect(info.limit, 1);

      // No `since`: the node republishes its info on its own schedule, so one
      // quiet for longer than the order window would never announce itself.
      expect(info.since, isNull);
    });

    test('keeps the order book on a request of its own', () {
      final repository = OpenOrdersRepository(nostrService, _settings());
      addTearDown(repository.dispose);

      final orders = requests[1].filters.single;
      expect(orders.kinds, [orderEventKind]);
      expect(orders.authors, [_nodePubkey]);
      expect(orders.since, isNotNull);
    });

    test('resubscribes both when the node changes', () {
      final repository = OpenOrdersRepository(nostrService, _settings());
      addTearDown(repository.dispose);
      requests.clear();

      repository.updateSettings(
        _settings().copyWith(mostroPublicKey: 'f' * 64),
      );

      expect(requests, hasLength(2));
      expect(requests.first.filters.single.kinds, [infoEventKind]);
      expect(requests.first.filters.single.authors, ['f' * 64]);
      expect(requests[1].filters.single.kinds, [orderEventKind]);
      expect(requests[1].filters.single.authors, ['f' * 64]);
    });
  });
}
