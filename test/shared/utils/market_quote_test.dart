import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/enums/role.dart';
import 'package:mostro_mobile/shared/utils/market_quote.dart';

/// A market-price order states no sats until the node resolves them, so the
/// figure on the settlement screen is the first the user sees of it. These
/// lock the re-pricing to mostrod's own arithmetic: a client that quoted
/// differently would flag every honest trade.
void main() {
  group('MarketQuote.satsFor', () {
    test('converts fiat at the given rate', () {
      // $100 at $50,000/BTC is 0.002 BTC.
      expect(
        MarketQuote.satsFor(
          fiatAmount: 100,
          fiatPerBtc: 50000,
          premium: 0,
        ),
        200000,
      );
    });

    test('a positive premium lowers the sats', () {
      // The maker charges 5% over the market, so the same fiat buys less.
      expect(
        MarketQuote.satsFor(
          fiatAmount: 100,
          fiatPerBtc: 50000,
          premium: 5,
        ),
        190000,
      );
    });

    test('a negative premium raises the sats', () {
      expect(
        MarketQuote.satsFor(
          fiatAmount: 100,
          fiatPerBtc: 50000,
          premium: -5,
        ),
        210000,
      );
    });

    test('truncates rather than rounds, as mostrod does on the cast', () {
      // 1 / 3 BTC-ish: the exact figure carries a fraction of a satoshi.
      final sats = MarketQuote.satsFor(
        fiatAmount: 1,
        fiatPerBtc: 30000.7,
        premium: 0,
      );
      final exact = (1 / 30000.7) * 100000000;

      expect(sats, exact.truncate());
      expect(sats, lessThan(exact));
    });

    test('is null when there is nothing to price', () {
      expect(
        MarketQuote.satsFor(fiatAmount: 0, fiatPerBtc: 50000, premium: 0),
        isNull,
      );
      expect(
        MarketQuote.satsFor(fiatAmount: -1, fiatPerBtc: 50000, premium: 0),
        isNull,
      );
    });

    test('is null for a rate that cannot price anything', () {
      for (final rate in [0.0, -1.0, double.nan, double.infinity]) {
        expect(
          MarketQuote.satsFor(fiatAmount: 100, fiatPerBtc: rate, premium: 0),
          isNull,
          reason: 'rate $rate',
        );
      }
    });

    test('is null for a premium that is not a number', () {
      expect(
        MarketQuote.satsFor(
          fiatAmount: 100,
          fiatPerBtc: 50000,
          premium: double.nan,
        ),
        isNull,
      );
    });

    test('is null when the premium would consume the whole quote', () {
      expect(
        MarketQuote.satsFor(
          fiatAmount: 100,
          fiatPerBtc: 50000,
          premium: 100,
        ),
        isNull,
      );
    });

    test('is null beyond what bitcoin can express', () {
      // A rate near zero makes any fiat amount worth more than every bitcoin.
      expect(
        MarketQuote.satsFor(
          fiatAmount: 100,
          fiatPerBtc: 0.0000001,
          premium: 0,
        ),
        isNull,
      );
    });
  });

  group('MarketQuote.deviation', () {
    test('is the gap as a fraction of the quote', () {
      expect(
        MarketQuote.deviation(quotedSats: 200000, settledSats: 180000),
        closeTo(0.1, 1e-9),
      );
    });

    test('has no direction', () {
      expect(
        MarketQuote.deviation(quotedSats: 200000, settledSats: 220000),
        closeTo(0.1, 1e-9),
      );
    });

    test('is null with no quote to be a fraction of', () {
      expect(
        MarketQuote.deviation(quotedSats: 0, settledSats: 200000),
        isNull,
      );
    });
  });

  group('MarketCheck', () {
    MarketCheck? check({required int settledSats, double premium = 0}) =>
        MarketCheck.of(
          settledSats: settledSats,
          fiatAmount: 100,
          fiatPerBtc: 50000,
          premium: premium,
        );

    test('an exact quote is on the market', () {
      final result = check(settledSats: 200000)!;

      expect(result.quotedSats, 200000);
      expect(result.deviation, 0);
      expect(result.isOffMarket, isFalse);
    });

    test('a move within tolerance is not worth raising', () {
      // 2% — inside what a different aggregate and a few minutes explain.
      expect(check(settledSats: 196000)!.isOffMarket, isFalse);
    });

    test('the shave the finding describes is caught', () {
      // The node tells the buyer to invoice for 10% less than the trade.
      final result = check(settledSats: 180000)!;

      expect(result.isOffMarket, isTrue);
      expect(result.isBelowMarket, isTrue);
    });

    test('an overcharge is caught too', () {
      final result = check(settledSats: 260000)!;

      expect(result.isOffMarket, isTrue);
      expect(result.isBelowMarket, isFalse);
    });

    test('the premium is accounted for before judging the gap', () {
      // A 10% premium legitimately puts the settlement 10% under the raw
      // market quote; without accounting for it this would read as a skim.
      final result = MarketCheck.of(
        settledSats: 180000,
        fiatAmount: 100,
        fiatPerBtc: 50000,
        premium: 10,
      )!;

      expect(result.quotedSats, 180000);
      expect(result.isOffMarket, isFalse);
    });

    test('is null when there is nothing to compare', () {
      expect(check(settledSats: 0), isNull);
      expect(
        MarketCheck.of(
          settledSats: 200000,
          fiatAmount: 0,
          fiatPerBtc: 50000,
          premium: 0,
        ),
        isNull,
      );
    });
  });

  group('MarketCheck.isAdverseTo', () {
    // Which direction hurts depends on the side of the trade.
    const below = MarketCheck(
      quotedSats: 200000,
      settledSats: 180000,
      deviation: 0.1,
    );
    const above = MarketCheck(
      quotedSats: 200000,
      settledSats: 220000,
      deviation: 0.1,
    );

    test('a payout under the quote shorts the buyer', () {
      expect(below.isAdverseTo(Role.buyer), isTrue);
      expect(below.isAdverseTo(Role.seller), isFalse);
    });

    test('a settlement over the quote takes more from the seller', () {
      expect(above.isAdverseTo(Role.seller), isTrue);
      expect(above.isAdverseTo(Role.buyer), isFalse);
    });
  });
}
