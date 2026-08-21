import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/shared/utils/bond_amounts.dart';

void main() {
  // A published policy: 2% of the order, never below 1000 sats.
  const pct = 0.02;
  const base = 1000;

  group('BondAmounts.expectedFor', () {
    test('takes the advertised percentage of the order', () {
      expect(
        BondAmounts.expectedFor(
            orderAmountSats: 500000, amountPct: pct, baseAmountSats: base),
        10000,
      );
    });

    test('never goes below the advertised floor', () {
      // 2% of 10000 is 200, which the floor lifts to 1000, so a tiny order
      // never yields a trivial bond.
      expect(
        BondAmounts.expectedFor(
            orderAmountSats: 10000, amountPct: pct, baseAmountSats: base),
        base,
      );
    });

    test('rounds to the nearest satoshi, as mostrod does', () {
      // 0.02 × 12525 = 250.5
      expect(
        BondAmounts.expectedFor(
            orderAmountSats: 12525, amountPct: pct, baseAmountSats: 0),
        251,
      );
    });

    test('is the floor when the order amount is not resolved', () {
      expect(
        BondAmounts.expectedFor(
            orderAmountSats: 0, amountPct: pct, baseAmountSats: base),
        base,
      );
    });

    test('is the floor when the node charges no percentage', () {
      expect(
        BondAmounts.expectedFor(
            orderAmountSats: 500000, amountPct: 0, baseAmountSats: base),
        base,
      );
    });
  });

  group('BondAmounts.problemWith', () {
    BondProblem? check({
      int? requested = 10000,
      int? orderAmount = 500000,
      bool advertised = true,
      double? amountPct = pct,
      int? baseAmountSats = base,
    }) =>
        BondAmounts.problemWith(
          requestedSats: requested,
          orderAmountSats: orderAmount,
          advertised: advertised,
          amountPct: amountPct,
          baseAmountSats: baseAmountSats,
        );

    test('accepts the figure the published policy yields', () {
      expect(check(), isNull);
    });

    // The finding's scenario: a small trade met with an arbitrarily large
    // bond, because nothing related the two.
    test('refuses a bond out of all proportion to the order', () {
      expect(check(requested: 10000000), BondProblem.wrongAmount);
    });

    test('refuses a bond below the advertised floor', () {
      expect(
        check(requested: 10, orderAmount: 0),
        BondProblem.belowFloor,
      );
    });

    test('refuses a request from a node that never advertised bonds', () {
      expect(check(advertised: false), BondProblem.notAdvertised);
      expect(check(amountPct: null), BondProblem.notAdvertised);
      expect(check(baseAmountSats: null), BondProblem.notAdvertised);
    });

    test('refuses a request with no amount at all', () {
      expect(check(requested: null), BondProblem.wrongAmount);
      expect(check(requested: 0), BondProblem.wrongAmount);
    });

    // A market-priced range order is sized from the taker's own quote, which
    // the node computes and never sends. Refusing there would refuse bonds
    // that are perfectly correct.
    test('checks only the floor when the order amount is unknown', () {
      expect(check(requested: base, orderAmount: null), isNull);
      expect(check(requested: 999999, orderAmount: null), isNull);
      expect(check(requested: base - 1, orderAmount: null),
          BondProblem.belowFloor);
    });

    test('the floor alone still holds when the order amount is zero', () {
      expect(check(requested: base, orderAmount: 0), isNull);
    });
  });
}
