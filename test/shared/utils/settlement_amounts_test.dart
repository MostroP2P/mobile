import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/shared/utils/settlement_amounts.dart';

void main() {
  // mostrod's default rate. Each side pays half of it, so the fee on a
  // 100 000 sat order is 0.006 × 100000 / 2 = 300 sats per side.
  const feeRate = 0.006;

  group('SettlementAmounts.feeFor', () {
    test('takes half the configured rate', () {
      expect(
          SettlementAmounts.feeFor(amountSats: 100000, feeRate: feeRate), 300);
    });

    test('rounds half away from zero, as mostrod does', () {
      // 0.001 × 1000 / 2 = 0.5
      expect(SettlementAmounts.feeFor(amountSats: 1000, feeRate: 0.001), 1);
      // 0.001 × 3000 / 2 = 1.5
      expect(SettlementAmounts.feeFor(amountSats: 3000, feeRate: 0.001), 2);
      // 0.001 × 2000 / 2 = 1.0
      expect(SettlementAmounts.feeFor(amountSats: 2000, feeRate: 0.001), 1);
    });

    test('is zero when the node charges nothing', () {
      // Distinct from null: a rate of zero is a term the settlement can be
      // checked against, an unusable rate is not.
      expect(SettlementAmounts.feeFor(amountSats: 100000, feeRate: 0), 0);
    });

    test('is null when there is no amount to charge on', () {
      expect(SettlementAmounts.feeFor(amountSats: 0, feeRate: feeRate), isNull);
      expect(
          SettlementAmounts.feeFor(amountSats: -1, feeRate: feeRate), isNull);
    });

    test('is null for a rate that is not a number', () {
      expect(
        SettlementAmounts.feeFor(amountSats: 100000, feeRate: double.nan),
        isNull,
      );
      expect(
        SettlementAmounts.feeFor(amountSats: 100000, feeRate: double.infinity),
        isNull,
      );
      expect(
        SettlementAmounts.feeFor(amountSats: 100000, feeRate: -0.006),
        isNull,
      );
    });

    test('is null for a finite rate that overflows the multiplication', () {
      // 1e308 is finite and clears every check on the rate itself, but the
      // product is infinity and rounding it throws.
      expect(
        SettlementAmounts.feeFor(amountSats: 200000, feeRate: 1e308),
        isNull,
      );
    });

    test('is null for a finite rate that would saturate the result', () {
      // The quieter half of the same bug: this product stays finite, so
      // round() does not throw — it pins to the int64 ceiling and hands back
      // a figure the node never asked for.
      expect(
        SettlementAmounts.feeFor(amountSats: 200000, feeRate: 1e30),
        isNull,
      );
    });

    test('is null for an amount beyond the supply cap', () {
      expect(
        SettlementAmounts.feeFor(
            amountSats: SettlementAmounts.maxSats + 1, feeRate: feeRate),
        isNull,
      );
    });
  });

  group('SettlementAmounts.sellerPays', () {
    // The seller covers the order plus their half of the fee, which is why
    // the hold invoice is never simply the order amount.
    test('adds the seller half of the fee to the order amount', () {
      expect(
        SettlementAmounts.sellerPays(amountSats: 100000, feeRate: feeRate),
        100300,
      );
    });

    test('is the order amount when the node charges nothing', () {
      expect(
        SettlementAmounts.sellerPays(amountSats: 100000, feeRate: 0),
        100000,
      );
    });

    test('is null when the order amount is not resolved yet', () {
      // A market-price order reads zero until it is taken. Treating that as a
      // real figure would expect a settlement of exactly the fee.
      expect(SettlementAmounts.sellerPays(amountSats: 0, feeRate: feeRate),
          isNull);
      expect(SettlementAmounts.sellerPays(amountSats: -5, feeRate: feeRate),
          isNull);
    });

    test('is null for a rate that is not a number', () {
      expect(
        SettlementAmounts.sellerPays(amountSats: 100000, feeRate: double.nan),
        isNull,
      );
    });

    test('is null rather than crashing on an extreme finite rate', () {
      // The settlement screen reads this on build, so an unguarded rate here
      // took the screen down instead of reporting a check it could not make.
      expect(
        SettlementAmounts.sellerPays(amountSats: 200000, feeRate: 1e308),
        isNull,
      );
      expect(
        SettlementAmounts.sellerPays(amountSats: 200000, feeRate: 1e30),
        isNull,
      );
    });
  });

  group('SettlementAmounts.buyerReceives', () {
    test('subtracts the buyer half of the fee from the order amount', () {
      expect(
        SettlementAmounts.buyerReceives(amountSats: 100000, feeRate: feeRate),
        99700,
      );
    });

    test('is the order amount when the node charges nothing', () {
      expect(
        SettlementAmounts.buyerReceives(amountSats: 100000, feeRate: 0),
        100000,
      );
    });

    test('is null when the order amount is not resolved yet', () {
      expect(SettlementAmounts.buyerReceives(amountSats: 0, feeRate: feeRate),
          isNull);
    });

    test('is null when the fee would consume the whole order', () {
      // Nothing is left to invoice for, so there is no figure to check
      // against rather than a figure of zero.
      expect(
        SettlementAmounts.buyerReceives(amountSats: 10, feeRate: 2.0),
        isNull,
      );
    });

    test('is null rather than crashing on an extreme finite rate', () {
      expect(
        SettlementAmounts.buyerReceives(amountSats: 200000, feeRate: 1e308),
        isNull,
      );
      expect(
        SettlementAmounts.buyerReceives(amountSats: 200000, feeRate: 1e30),
        isNull,
      );
    });
  });

  group('the two sides against one order', () {
    test('differ by the whole fee, half on each side', () {
      const amount = 250000;
      final seller =
          SettlementAmounts.sellerPays(amountSats: amount, feeRate: feeRate)!;
      final buyer = SettlementAmounts.buyerReceives(
          amountSats: amount, feeRate: feeRate)!;
      final half =
          SettlementAmounts.feeFor(amountSats: amount, feeRate: feeRate)!;

      expect(seller - buyer, half * 2);
      expect(seller - amount, half);
      expect(amount - buyer, half);
    });
  });

  // The two figures a client is asked to act on, against the same order.
  // Comparing either side against the order amount itself would refuse every
  // correct settlement, which is why the derivation exists at all.
  group('what the finding describes', () {
    test('a payout request for the order amount is not what the order pays',
        () {
      const amount = 100000;
      final expected =
          SettlementAmounts.buyerReceives(amountSats: amount, feeRate: feeRate);

      expect(expected, isNot(amount));
      expect(expected, 99700);
    });

    test('a hold invoice for the order amount is not what the seller owes', () {
      const amount = 100000;
      final expected =
          SettlementAmounts.sellerPays(amountSats: amount, feeRate: feeRate);

      expect(expected, isNot(amount));
      expect(expected, 100300);
    });

    test('an order skimmed by a tenth is nowhere near either figure', () {
      // The finding's scenario: the trade is for 100000, the request says
      // 90000, and the difference is kept.
      const amount = 100000;
      const skimmed = 90000;
      final expected = SettlementAmounts.buyerReceives(
          amountSats: amount, feeRate: feeRate)!;

      expect(skimmed, isNot(expected));
      expect(expected - skimmed, 9700);
    });
  });
}
