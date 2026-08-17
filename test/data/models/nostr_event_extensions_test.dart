import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:timeago/timeago.dart' as timeago;

/// Builds a kind 38383 order event with the tags the Mostro protocol defines.
NostrEvent orderEvent({List<List<String>>? tags, DateTime? createdAt}) =>
    NostrEvent(
      id: 'event-id',
      kind: 38383,
      content: '',
      sig: 'sig',
      pubkey: 'a' * 64,
      createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
      tags: tags ??
          const [
            ['d', 'order-1'],
            ['k', 'sell'],
            ['f', 'USD'],
            ['s', 'pending'],
            ['amt', '50000'],
            ['fa', '100'],
            ['pm', 'Bank Transfer', 'Cash in person'],
            ['premium', '3'],
            ['source', 'https://example.test'],
            ['network', 'mainnet'],
            ['layer', 'lightning'],
            ['name', 'anonymous-finney'],
            ['g', 'u4pruyd'],
            ['bond', '1000'],
            ['expiration', '1700000000'],
            ['expires_at', '1700003600'],
            ['y', 'mostro'],
            ['z', 'order'],
            [
              'p',
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
            ],
          ],
    );

void main() {
  group('NostrEventExtensions tag accessors', () {
    test('reads every single-value tag', () {
      final event = orderEvent();

      expect(event.orderId, 'order-1');
      expect(event.recipient, 'b' * 64);
      expect(event.orderType, OrderType.sell);
      expect(event.currency, 'USD');
      expect(event.status, Status.pending);
      expect(event.amount, '50000');
      expect(event.premium, '3');
      expect(event.source, 'https://example.test');
      expect(event.network, 'mainnet');
      expect(event.layer, 'lightning');
      expect(event.name, 'anonymous-finney');
      expect(event.geohash, 'u4pruyd');
      expect(event.bond, '1000');
      expect(event.expiresAt, '1700003600');
      expect(event.platform, 'mostro');
      expect(event.type, 'order');
    });

    test('returns null for tags that are absent', () {
      final event = orderEvent(tags: const [
        ['s', 'pending'],
      ]);

      expect(event.orderId, isNull);
      expect(event.recipient, isNull);
      expect(event.orderType, isNull);
      expect(event.currency, isNull);
      expect(event.amount, isNull);
      expect(event.premium, isNull);
      expect(event.source, isNull);
      expect(event.network, isNull);
      expect(event.layer, isNull);
      expect(event.geohash, isNull);
      expect(event.bond, isNull);
      expect(event.expiresAt, isNull);
      expect(event.platform, isNull);
    });

    test('falls back to "Anon" when there is no name tag', () {
      expect(orderEvent(tags: const []).name, 'Anon');
    });

    test('parses a buy order kind', () {
      final event = orderEvent(tags: const [
        ['k', 'buy']
      ]);

      expect(event.orderType, OrderType.buy);
    });

    test('reads every payment method from the pm tag', () {
      expect(orderEvent().paymentMethods, ['Bank Transfer', 'Cash in person']);
    });

    test('returns no payment methods when the pm tag is missing or bare', () {
      expect(orderEvent(tags: const []).paymentMethods, isEmpty);
      expect(
        orderEvent(tags: const [
          ['pm']
        ]).paymentMethods,
        isEmpty,
      );
    });

    test('parses a single fiat amount', () {
      final amount = orderEvent().fiatAmount;

      expect(amount.minimum, 100);
      expect(amount.maximum, isNull);
      expect(amount.isRange(), isFalse);
    });

    test('parses a fiat amount range', () {
      final amount = orderEvent(tags: const [
        ['fa', '100', '500']
      ]).fiatAmount;

      expect(amount.minimum, 100);
      expect(amount.maximum, 500);
      expect(amount.isRange(), isTrue);
    });

    test('falls back to an empty amount when the fa tag is missing', () {
      final amount = orderEvent(tags: const []).fiatAmount;

      expect(amount.minimum, 0);
      expect(amount.maximum, isNull);
    });

    test('parses the rating tag', () {
      final event = orderEvent(tags: const [
        ['rating', '{"total_reviews":5,"total_rating":4.5,"days":30}']
      ]);

      expect(event.rating, isNotNull);
      expect(event.rating!.totalReviews, 5);
      expect(event.rating!.totalRating, 4.5);
    });

    test('returns no rating when the tag is missing', () {
      expect(orderEvent(tags: const []).rating, isNull);
    });

    test('shifts the expiration timestamp back by twelve hours', () {
      final expiration = orderEvent().expirationDate;

      expect(
        expiration,
        DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000)
            .subtract(const Duration(hours: 12)),
      );
    });

    test('throws when reading a status tag that is absent', () {
      expect(() => orderEvent(tags: const []).status, throwsA(anything));
    });

    test('throws when reading a type tag that is absent', () {
      expect(() => orderEvent(tags: const []).type, throwsA(anything));
    });
  });

  group('NostrEventExtensions.timeAgoWithLocale', () {
    setUpAll(() => timeago.setLocaleMessages('es', timeago.EsMessages()));

    test('formats the creation time in the requested locale', () {
      final event = orderEvent(
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      );

      expect(event.timeAgoWithLocale('en'), contains('hour'));
      expect(event.timeAgoWithLocale('es'), contains('hora'));
    });

    test('allows timestamps in the future', () {
      final event = orderEvent(
        createdAt: DateTime.now().add(const Duration(hours: 2)),
      );

      expect(event.timeAgoWithLocale('en'), isNotEmpty);
    });
  });

  group('NostrEventExtensions.mostroUnWrap', () {
    test('rejects an event that is not a gift wrap', () async {
      await expectLater(
        orderEvent().mostroUnWrap(NostrKeyPairs(private: '1' * 64)),
        throwsArgumentError,
      );
    });

    test('rejects a gift wrap with empty content', () async {
      final event = NostrEvent(
        id: 'id',
        kind: 1059,
        content: '',
        sig: 'sig',
        pubkey: 'a' * 64,
        createdAt: DateTime.utc(2026),
        tags: const [],
      );

      await expectLater(
        event.mostroUnWrap(NostrKeyPairs(private: '1' * 64)),
        throwsArgumentError,
      );
    });
  });
}
