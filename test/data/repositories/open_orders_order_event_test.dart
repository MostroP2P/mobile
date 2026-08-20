import 'dart:async';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/repositories/open_orders_repository.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

import '../../mocks.mocks.dart';

/// Builds a kind-38383 order event of the shape mostrod publishes: empty
/// content, everything carried in tags (NIP-69).
NostrEvent _signedOrderEvent(
  NostrKeyPairs keyPair, {
  String orderId = 'order-1',
  String amount = '50000',
  String rating = '5',
  List<List<String>>? tags,
}) {
  return NostrEvent.fromPartialData(
    kind: 38383,
    content: '',
    keyPairs: keyPair,
    tags: tags ??
        [
          ['d', orderId],
          ['k', 'sell'],
          ['f', 'USD'],
          ['s', 'pending'],
          ['amt', amount],
          ['rating', rating],
          ['y', 'mostro'],
          ['z', 'order'],
        ],
  );
}

/// Re-tags [source] while keeping its original id/sig/pubkey — what a relay
/// can do for free, and what `NostrEvent.isVerified()` fails to catch because
/// it never recomputes the id from the serialized event.
NostrEvent _reTagged(NostrEvent source, List<List<String>> tags) {
  return NostrEvent(
    id: source.id,
    sig: source.sig,
    pubkey: source.pubkey,
    kind: source.kind,
    content: source.content,
    createdAt: source.createdAt,
    tags: tags,
  );
}

void main() {
  late MockNostrService mockNostrService;
  late StreamController<NostrEvent> eventController;
  late NostrKeyPairs nodeKeys;
  late Settings settings;

  setUp(() {
    nodeKeys = NostrUtils.generateKeyPair();
    mockNostrService = MockNostrService();
    eventController = StreamController<NostrEvent>.broadcast();

    settings = Settings(
      relays: const ['wss://relay.example'],
      fullPrivacyMode: false,
      mostroPublicKey: nodeKeys.public,
    );

    when(mockNostrService.isInitialized).thenReturn(true);
    when(mockNostrService.subscribeToEvents(any))
        .thenAnswer((_) => eventController.stream);
  });

  tearDown(() async {
    await eventController.close();
  });

  OpenOrdersRepository buildRepository() =>
      OpenOrdersRepository(mockNostrService, settings);

  // The subscription filter pins `authors` and `kinds`, but the pinned
  // dart_nostr fork forwards relay EVENT frames without verifying them or
  // matching them against the filter. Everything below is therefore reachable
  // by any relay the app is connected to.
  group('OpenOrdersRepository order event (kind 38383) verification', () {
    test('accepts a genuinely signed order from the configured node', () async {
      final repository = buildRepository();
      final event = _signedOrderEvent(nodeKeys);

      eventController.add(event);
      await pumpEventQueue();

      expect(await repository.getOrderById('order-1'), isNotNull);
    });

    test('rejects an order authored by anyone else', () async {
      final impostor = NostrUtils.generateKeyPair();
      final repository = buildRepository();

      eventController.add(_signedOrderEvent(impostor));
      await pumpEventQueue();

      expect(await repository.getAllOrders(), isEmpty);
    });

    test('rejects an order whose tags were rewritten under a genuine id',
        () async {
      final repository = buildRepository();
      final genuine = _signedOrderEvent(nodeKeys, amount: '50000', rating: '1');

      // The amount and the maker's rating are exactly what a user reads before
      // deciding to trade, and re-tagging costs the relay nothing.
      final tampered = _reTagged(genuine, [
        ['d', 'order-1'],
        ['k', 'sell'],
        ['f', 'USD'],
        ['s', 'pending'],
        ['amt', '1'],
        ['rating', '5'],
        ['y', 'mostro'],
        ['z', 'order'],
      ]);

      eventController.add(tampered);
      await pumpEventQueue();

      expect(await repository.getAllOrders(), isEmpty);
    });

    test('a tampered copy cannot displace an order already accepted', () async {
      final repository = buildRepository();
      final genuine = _signedOrderEvent(nodeKeys, amount: '50000');

      eventController.add(genuine);
      await pumpEventQueue();

      eventController.add(_reTagged(genuine, [
        ['d', 'order-1'],
        ['z', 'order'],
        ['amt', '1'],
      ]));
      await pumpEventQueue();

      final stored = await repository.getOrderById('order-1');
      expect(stored!.amount, '50000');
    });

    test('ignores an event that carries no d tag instead of throwing',
        () async {
      final repository = buildRepository();
      final event = _signedOrderEvent(nodeKeys, tags: [
        ['k', 'sell'],
        ['z', 'order'],
      ]);

      eventController.add(event);
      await pumpEventQueue();

      expect(await repository.getAllOrders(), isEmpty);
    });

    test('ignores an event that carries no z tag instead of throwing',
        () async {
      // This used to throw inside the stream callback: `type` bang-asserted
      // the tag, and an event without one reached it before any other check.
      final repository = buildRepository();
      final event = _signedOrderEvent(nodeKeys, tags: [
        ['d', 'order-1'],
        ['k', 'sell'],
      ]);

      eventController.add(event);
      await pumpEventQueue();

      expect(await repository.getAllOrders(), isEmpty);
    });

    test('ignores a non-order z value on the order kind', () async {
      final repository = buildRepository();
      final event = _signedOrderEvent(nodeKeys, tags: [
        ['d', 'order-1'],
        ['z', 'something-else'],
      ]);

      eventController.add(event);
      await pumpEventQueue();

      expect(await repository.getAllOrders(), isEmpty);
    });

    test('ignores z=order carried on a kind the order book does not serve',
        () async {
      // The z tag alone used to be the whole admission test, with no kind
      // check in front of it.
      final repository = buildRepository();
      final event = NostrEvent.fromPartialData(
        kind: 1,
        content: 'not an order',
        keyPairs: nodeKeys,
        tags: [
          ['d', 'order-1'],
          ['z', 'order'],
        ],
      );

      eventController.add(event);
      await pumpEventQueue();

      expect(await repository.getAllOrders(), isEmpty);
    });
  });
}
