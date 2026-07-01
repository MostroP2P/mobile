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
  });
}
