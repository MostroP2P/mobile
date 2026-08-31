import 'dart:async';

import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/data/repositories/open_orders_repository.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';

import '../../mocks.mocks.dart';

/// `eventProvider(orderId)` used to scan the whole book with
/// `lastWhereOrNull` — O(orders) per family instance per emission, and every
/// `OrderNotifier` consulted it on every emission: O(sessions × orders) per
/// incoming public event. It is now an O(1) lookup on `orderMapProvider`.
void main() {
  const mostroPubkey = 'mostro-pubkey';

  late StreamController<NostrEvent> relay;
  late OpenOrdersRepository repo;
  late ProviderContainer container;

  NostrEvent order(String id, {required int createdAt}) => NostrEvent(
        id: 'event-$id-$createdAt',
        kind: 38383,
        content: '',
        sig: '',
        pubkey: mostroPubkey,
        createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
        tags: [
          ['d', id],
          ['z', 'order'],
          ['s', 'pending'],
        ],
      );

  setUp(() {
    relay = StreamController<NostrEvent>.broadcast();
    final nostr = MockNostrService();
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
    container = ProviderContainer(overrides: [
      orderRepositoryProvider.overrideWithValue(repo),
    ]);
    // Keep the stream chain alive from the start: without a listener the
    // StreamProvider stays in loading and the derived map reads empty.
    container.listen(orderMapProvider, (_, __) {});
  });

  tearDown(() async {
    container.dispose();
    repo.dispose();
    await relay.close();
  });

  // Generous settle window: covers both immediate emissions and the
  // coalesced emissions introduced by the order-book debounce PR.
  Future<void> flush() =>
      Future<void>.delayed(const Duration(milliseconds: 200));

  test('orderMapProvider indexes the book by order id', () async {
    relay
      ..add(order('a', createdAt: 100))
      ..add(order('b', createdAt: 101));
    await flush();

    final map = container.read(orderMapProvider);
    expect(map.keys, containsAll(['a', 'b']));
    expect(map['a']!.id, 'event-a-100');
  });

  test('eventProvider resolves through the map', () async {
    relay.add(order('a', createdAt: 100));
    await flush();

    expect(container.read(eventProvider('a'))!.id, 'event-a-100');
    expect(container.read(eventProvider('missing')), isNull);
  });

  test('an unrelated order does not notify an eventProvider listener',
      () async {
    relay.add(order('a', createdAt: 100));
    await flush();
    expect(container.read(eventProvider('a')), isNotNull,
        reason: 'precondition: the map already carries order a');
    var notifications = 0;
    container.listen(eventProvider('a'), (_, __) => notifications++);

    relay.add(order('b', createdAt: 200));
    await flush();

    expect(notifications, 0);
    expect(container.read(eventProvider('b')), isNotNull);
  });
}
