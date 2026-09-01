import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/features/mostro/transport.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager.dart';

void main() {
  group('buildOrdersFilter (transport-aware orders subscription)', () {
    final mostroPubkey = 'a' * 64;
    final tradeKeys = ['b' * 64, 'c' * 64];

    test('v1 (giftWrap) → kind 1059, no authors pin', () {
      final filter = buildOrdersFilter(
        Transport.giftWrap,
        tradeKeys,
        mostroPubkey,
      );

      expect(filter.kinds, [1059]);
      expect(filter.p, tradeKeys);
      expect(filter.authors, isNull);
    });

    test('v2 (nip44) → kind 14 authored by the node, addressed to trade keys',
        () {
      final filter = buildOrdersFilter(
        Transport.nip44,
        tradeKeys,
        mostroPubkey,
      );

      expect(filter.kinds, [14]);
      expect(filter.authors, [mostroPubkey]);
      expect(filter.p, tradeKeys);
    });

    // Without a since every (re)subscription replayed the node's full message
    // history from every relay; kind 14 carries real timestamps, so a
    // persisted cursor can bound the replay tightly.
    test('v2 (nip44) bounds the replay with since and no limit', () {
      final since = DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000);
      final filter = buildOrdersFilter(
        Transport.nip44,
        tradeKeys,
        mostroPubkey,
        since: since,
      );

      expect(filter.since, since);
      // A limit on top of since would be answered with the *newest* n,
      // silently dropping the rest of the window. Those events are never
      // delivered, so they never hold the cursor back and are lost for good.
      expect(filter.limit, isNull);
    });

    test('v1 (giftWrap) ignores since: its timestamps are randomized', () {
      final filter = buildOrdersFilter(
        Transport.giftWrap,
        tradeKeys,
        mostroPubkey,
        since: DateTime.now(),
      );

      expect(filter.since, isNull);
    });
  });
}
