import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/session.dart';

/// The settlement checks are held to the terms pinned when the session
/// committed, so those figures have to survive a restart — and their absence
/// in a session written before they existed has to read as "nothing pinned"
/// rather than as a parse failure that would strand the trade.
void main() {
  final keyPair = NostrKeyPairs(
    private:
        '0000000000000000000000000000000000000000000000000000000000000001',
  );

  Map<String, dynamic> baseJson() => {
        'master_key': keyPair,
        'trade_key': keyPair,
        'key_index': 0,
        'full_privacy': false,
        'start_time': '2026-06-03T12:00:00.000',
        'order_id': 'order-1',
      };

  Session decode(Map<String, dynamic> extra) =>
      Session.fromJson({...baseJson(), ...extra});

  group('Session pinned terms', () {
    test('round-trip through JSON keeps both figures', () {
      final session = Session(
        masterKey: keyPair,
        tradeKey: keyPair,
        keyIndex: 0,
        fullPrivacy: false,
        startTime: DateTime.parse('2026-06-03T12:00:00.000'),
        orderId: 'order-1',
        pinnedAmountSats: 100000,
        pinnedFeeRate: 0.006,
      );

      final restored = Session.fromJson({
        ...session.toJson(),
        'master_key': keyPair,
        'trade_key': keyPair,
      });

      expect(restored.pinnedAmountSats, 100000);
      expect(restored.pinnedFeeRate, 0.006);
    });

    test('round-trip through JSON keeps the pricing terms', () {
      // The market quote is priced from these three, and all three live in
      // the same addressable event as the sats amount.
      final session = Session(
        masterKey: keyPair,
        tradeKey: keyPair,
        keyIndex: 0,
        fullPrivacy: false,
        startTime: DateTime.parse('2026-06-03T12:00:00.000'),
        orderId: 'order-1',
        pinnedFiatCode: 'USD',
        pinnedFiatAmount: 100,
        pinnedPremium: 2.5,
      );

      final restored = Session.fromJson({
        ...session.toJson(),
        'master_key': keyPair,
        'trade_key': keyPair,
      });

      expect(restored.pinnedFiatCode, 'USD');
      expect(restored.pinnedFiatAmount, 100);
      expect(restored.pinnedPremium, 2.5);
    });

    test('a zero premium is pinned rather than dropped', () {
      // Zero is a real term: an order at no premium is priced from the market
      // rate exactly. Dropping it would read as "nothing pinned" and put the
      // check back on whatever the node publishes next.
      final restored = decode({'pinned_premium': 0});
      expect(restored.pinnedPremium, 0);
    });

    test('pricing terms that are not usable figures read as unpinned', () {
      final restored = decode({
        'pinned_fiat_code': '',
        'pinned_fiat_amount': 0,
        'pinned_premium': double.nan,
      });

      expect(restored.pinnedFiatCode, isNull);
      expect(restored.pinnedFiatAmount, isNull);
      expect(restored.pinnedPremium, isNull);
    });

    test('a session written before the pricing pins existed reads as unpinned',
        () {
      final restored = decode({'pinned_amount_sats': 100000});

      expect(restored.pinnedFiatCode, isNull);
      expect(restored.pinnedFiatAmount, isNull);
      expect(restored.pinnedPremium, isNull);
    });

    test('a session written before the pin existed reads as unpinned', () {
      final session = decode(const {});

      expect(session.pinnedAmountSats, isNull);
      expect(session.pinnedFeeRate, isNull);
    });

    test('explicit nulls read as unpinned', () {
      final session = decode(const {
        'pinned_amount_sats': null,
        'pinned_fee_rate': null,
      });

      expect(session.pinnedAmountSats, isNull);
      expect(session.pinnedFeeRate, isNull);
    });

    test('string-encoded figures are read', () {
      final session = decode(const {
        'pinned_amount_sats': '100000',
        'pinned_fee_rate': '0.006',
      });

      expect(session.pinnedAmountSats, 100000);
      expect(session.pinnedFeeRate, 0.006);
    });

    test('an integer fee rate is widened rather than dropped', () {
      expect(decode(const {'pinned_fee_rate': 0}).pinnedFeeRate, 0.0);
    });

    test('an amount that is not a usable figure reads as unpinned', () {
      expect(decode(const {'pinned_amount_sats': 0}).pinnedAmountSats, isNull);
      expect(decode(const {'pinned_amount_sats': -1}).pinnedAmountSats, isNull);
      expect(
        decode(const {'pinned_amount_sats': 'not a number'}).pinnedAmountSats,
        isNull,
      );
    });

    test('a fee rate that is not a usable figure reads as unpinned', () {
      expect(decode(const {'pinned_fee_rate': -0.1}).pinnedFeeRate, isNull);
      expect(
        decode({'pinned_fee_rate': double.nan}).pinnedFeeRate,
        isNull,
      );
      expect(
        decode({'pinned_fee_rate': double.infinity}).pinnedFeeRate,
        isNull,
      );
      expect(
        decode(const {'pinned_fee_rate': 'not a number'}).pinnedFeeRate,
        isNull,
      );
    });

    test('records that pinning ran, and survives a round trip', () {
      final session = Session(
        masterKey: keyPair,
        tradeKey: keyPair,
        keyIndex: 0,
        fullPrivacy: false,
        startTime: DateTime.parse('2026-06-03T12:00:00.000'),
        orderId: 'order-1',
        termsPinned: true,
      );

      final restored = Session.fromJson({
        ...session.toJson(),
        'master_key': keyPair,
        'trade_key': keyPair,
      });

      expect(restored.termsPinned, isTrue);
    });

    test('a session written before the marker existed reads as unpinned', () {
      expect(decode(const {}).termsPinned, isFalse);
      expect(decode(const {'terms_pinned': null}).termsPinned, isFalse);
    });

    test('a string-encoded marker is read', () {
      expect(decode(const {'terms_pinned': 'true'}).termsPinned, isTrue);
      expect(decode(const {'terms_pinned': 'false'}).termsPinned, isFalse);
    });
  });
}
