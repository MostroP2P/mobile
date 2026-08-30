import 'dart:async';

import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/repositories/open_orders_repository.dart';
import 'package:mostro_mobile/features/settings/settings.dart';

import '../../mocks.mocks.dart';

/// The order book repository used to emit a fresh copy of the whole book for
/// every kind-38383 event from every relay, with no deduplication: a 48 h
/// replay from R relays produced R×M list emissions, each re-sorting and
/// re-filtering downstream. Emissions are now coalesced per debounce window
/// and stale/duplicate relay copies are dropped by (orderId, created_at).
void main() {
  const mostroPubkey = 'mostro-pubkey';

  late MockNostrService nostr;
  late StreamController<NostrEvent> relay;
  late OpenOrdersRepository repo;

  NostrEvent order(String id,
      {required int createdAt, String status = 'pending'}) {
    return NostrEvent(
      id: 'event-$id-$createdAt',
      kind: 38383,
      content: '',
      sig: '',
      pubkey: mostroPubkey,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
      tags: [
        ['d', id],
        ['z', 'order'],
        ['s', status],
      ],
    );
  }

  setUp(() {
    relay = StreamController<NostrEvent>.broadcast();
    nostr = MockNostrService();
    when(nostr.isInitialized).thenReturn(true);
    when(nostr.subscribeToEvents(any)).thenAnswer((_) => relay.stream);
    repo = OpenOrdersRepository(
      nostr,
      Settings(
        relays: const ['wss://relay.a'],
        fullPrivacyMode: false,
        mostroPublicKey: mostroPubkey,
      ),
    );
  });

  tearDown(() async {
    repo.dispose();
    await relay.close();
  });

  test('coalesces a burst of events into a single emission', () async {
    // Arrange
    final emissions = <List<NostrEvent>>[];
    final sub = repo.eventsStream.skip(1).listen(emissions.add);
    addTearDown(sub.cancel);

    // Act: a replay burst of three different orders
    relay
      ..add(order('a', createdAt: 100))
      ..add(order('b', createdAt: 101))
      ..add(order('c', createdAt: 102));
    await Future<void>.delayed(
      OpenOrdersRepository.emitDebounce + const Duration(milliseconds: 20),
    );

    // Assert: one coalesced emission carrying the three orders
    expect(emissions, hasLength(1));
    expect(emissions.single, hasLength(3));
  });

  test('drops stale relay copies of an order', () async {
    // Act: newest first, then an older copy from another relay
    relay
      ..add(order('a', createdAt: 200, status: 'canceled'))
      ..add(order('a', createdAt: 100, status: 'pending'));
    await Future<void>.delayed(
      OpenOrdersRepository.emitDebounce + const Duration(milliseconds: 20),
    );

    // Assert: the older event must not overwrite the newer state
    final kept = await repo.getOrderById('a');
    expect(kept!.status.toString(), contains('canceled'));
  });

  test('keeps the newer copy when it arrives second', () async {
    relay
      ..add(order('a', createdAt: 100, status: 'pending'))
      ..add(order('a', createdAt: 200, status: 'canceled'));
    await Future<void>.delayed(
      OpenOrdersRepository.emitDebounce + const Duration(milliseconds: 20),
    );

    final kept = await repo.getOrderById('a');
    expect(kept!.status.toString(), contains('canceled'));
  });
}
