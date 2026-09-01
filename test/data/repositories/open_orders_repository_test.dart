import 'dart:async';

import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/model/request/request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/repositories/open_orders_repository.dart';
import 'package:mostro_mobile/features/mostro/mostro_instance.dart';
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
  late StreamController<int> relayGeneration;
  late OpenOrdersRepository repo;

  NostrEvent order(String id,
      {required int createdAt, String status = 'pending', String? eventId}) {
    return NostrEvent(
      id: eventId ?? 'event-$id-$createdAt',
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

  NostrEvent info({required int createdAt, required int pow}) {
    return NostrEvent(
      id: 'info-$createdAt-$pow',
      kind: 38385,
      content: '',
      sig: '',
      pubkey: mostroPubkey,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
      tags: [
        ['d', 'mostro'],
        ['z', 'info'],
        ['pow', '$pow'],
      ],
    );
  }

  /// Signals EOSE for every live relay on the current subscription, which is
  /// what lets the repository trust its cursor.
  void completeReplay() {
    final onEose = verify(nostr.subscribeToEvents(any,
            onEose: captureAnyNamed('onEose')))
        .captured
        .last as void Function(String)?;
    onEose?.call('wss://relay.a');
  }

  setUp(() {
    relay = StreamController<NostrEvent>.broadcast();
    relayGeneration = StreamController<int>.broadcast();
    nostr = MockNostrService();
    when(nostr.isInitialized).thenReturn(true);
    when(nostr.relayGenerationStream).thenAnswer((_) => relayGeneration.stream);
    when(nostr.liveRelayCount).thenReturn(1);
    when(nostr.subscribeToEvents(any, onEose: anyNamed('onEose')))
        .thenAnswer((_) => relay.stream);
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
    await relayGeneration.close();
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

  test('reloadData resumes from the last received event, not 48h back',
      () async {
    final recent =
        DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/
            1000;
    relay.add(order('a', createdAt: recent));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    completeReplay();

    repo.reloadData();

    final captured =
        verify(nostr.subscribeToEvents(captureAny, onEose: anyNamed('onEose'))).captured.cast<NostrRequest>();
    final since = captured.last.filters.first.since!;
    // Pinned exactly: the last received event minus the resume overlap, so a
    // change to either end of the window fails here instead of sliding by.
    expect(
      since,
      DateTime.fromMillisecondsSinceEpoch(recent * 1000)
          .subtract(OpenOrdersRepository.resumeOverlap),
      reason: 'the in-memory cache retains older orders; only the missed '
          'window (plus the overlap) needs replaying',
    );
  });

  test('an interrupted replay keeps the full lookback', () async {
    // A reloadData while the cold-start replay is still streaming cancels it.
    // Relays commonly serve stored events newest-first, so the undelivered
    // tail is older than the first event seen: resuming from it would drop
    // that tail for good.
    final recent =
        DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/
            1000;
    relay.add(order('a', createdAt: recent));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    // Deliberately no completeReplay(): no EOSE arrived.

    repo.reloadData();

    final captured =
        verify(nostr.subscribeToEvents(captureAny, onEose: anyNamed('onEose'))).captured.cast<NostrRequest>();
    final since = captured.last.filters.first.since!;
    expect(
      since.isBefore(DateTime.now().subtract(const Duration(hours: 47))),
      isTrue,
      reason: 'without EOSE the replay is not known complete, so the cursor '
          'cannot be trusted',
    );
  });

  test('a relay joining the set restores the full lookback', () async {
    // A relay connected after the REQ opened holds orders this cache has
    // never seen, so the cache is no longer complete for the set about to be
    // queried. Narrowing here would remove the last automatic recovery path
    // for the missing-38383 bug.
    final recent =
        DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/
            1000;
    relay.add(order('a', createdAt: recent));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    completeReplay();

    relayGeneration.add(2);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    repo.reloadData();

    final captured =
        verify(nostr.subscribeToEvents(captureAny, onEose: anyNamed('onEose'))).captured.cast<NostrRequest>();
    final since = captured.last.filters.first.since!;
    expect(
      since.isBefore(DateTime.now().subtract(const Duration(hours: 47))),
      isTrue,
      reason: 'the new relay may hold older orders the cache never saw',
    );
  });

  test('a future-dated event does not advance the resume cursor', () async {
    // A node clock running ahead must not push the window past events that
    // have not been seen.
    final future =
        DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch ~/
            1000;
    relay.add(order('a', createdAt: future));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    completeReplay();

    repo.reloadData();

    final captured =
        verify(nostr.subscribeToEvents(captureAny, onEose: anyNamed('onEose'))).captured.cast<NostrRequest>();
    final since = captured.last.filters.first.since!;
    expect(
      since.isBefore(DateTime.now().subtract(const Duration(hours: 47))),
      isTrue,
      reason: 'no trustworthy cursor was recorded, so the full lookback stays',
    );
  });

  test('a node switch resets the resume window to the cold-start lookback',
      () async {
    final recent =
        DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/
            1000;
    relay.add(order('a', createdAt: recent));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    completeReplay();

    repo.updateSettings(Settings(
      relays: const ['wss://relay.a'],
      fullPrivacyMode: false,
      mostroPublicKey: 'other-node',
    ));

    final captured =
        verify(nostr.subscribeToEvents(captureAny, onEose: anyNamed('onEose'))).captured.cast<NostrRequest>();
    final since = captured.last.filters.first.since!;
    expect(
      since.isBefore(DateTime.now().subtract(const Duration(hours: 47))),
      isTrue,
      reason: 'the cache was cleared, so the full lookback applies again',
    );
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

  test('breaks created_at ties by the lower event id, whichever arrives first',
      () async {
    // Two replacements published in the same second: NIP-01 keeps the
    // lexicographically lower id, so both relay orderings must converge.
    relay
      ..add(order('a', createdAt: 100, status: 'pending', eventId: 'bbb'))
      ..add(order('a', createdAt: 100, status: 'canceled', eventId: 'aaa'));
    await Future<void>.delayed(
      OpenOrdersRepository.emitDebounce + const Duration(milliseconds: 20),
    );

    final kept = await repo.getOrderById('a');
    expect(kept!.id, 'aaa');
    expect(kept.status.toString(), contains('canceled'));
  });

  test('keeps the lower event id when the higher one arrives second', () async {
    relay
      ..add(order('a', createdAt: 100, status: 'canceled', eventId: 'aaa'))
      ..add(order('a', createdAt: 100, status: 'pending', eventId: 'bbb'));
    await Future<void>.delayed(
      OpenOrdersRepository.emitDebounce + const Duration(milliseconds: 20),
    );

    final kept = await repo.getOrderById('a');
    expect(kept!.id, 'aaa');
    expect(kept.status.toString(), contains('canceled'));
  });

  test('a stale relay copy cannot roll back the mostro instance info',
      () async {
    // Kind 38385 carries pow/protocol_version/order limits, so an older copy
    // replayed by a lagging relay must not overwrite the newer one.
    relay
      ..add(info(createdAt: 200, pow: 8))
      ..add(info(createdAt: 100, pow: 0));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(repo.mostroInstance!.pow, 8);
  });

  test('emits the mostro instance only once per distinct info event', () async {
    final seen = <NostrEvent>[];
    final sub = repo.mostroInstanceStream.listen(seen.add);
    addTearDown(sub.cancel);

    final duplicate = info(createdAt: 200, pow: 8);
    relay
      ..add(duplicate)
      ..add(duplicate)
      ..add(info(createdAt: 300, pow: 4));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(seen, hasLength(2));
    expect(seen.last.pow, 4);
  });
}
