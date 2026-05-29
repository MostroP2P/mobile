import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/shared/utils/order_amount_limits.dart';

void main() {
  group('fiatAmountLimits', () {
    test('rounds min up and max down to whole, valid fiat bounds', () {
      // 1 BTC = 100,000 USD. min 100 sats -> 0.10 USD, max 1,000,000 sats -> 1000 USD.
      final limits = fiatAmountLimits(
        minSats: 100,
        maxSats: 1000000,
        exchangeRate: 100000,
      );
      // 0.10 ceils to 1 (floored at 1), 1000 stays 1000.
      expect(limits.minFiat, 1);
      expect(limits.maxFiat, 1000);
      expect(limits.isDisplayable, isTrue);
    });

    test('floors the minimum at 1 when the converted value is below 1', () {
      // min converts to 0.5 -> shown as 1 (field rejects decimals and < 1).
      final limits = fiatAmountLimits(
        minSats: 50,
        maxSats: 1000000,
        exchangeRate: 100000,
      );
      expect(limits.minFiat, 1);
    });

    test('rounds a fractional minimum up to the next whole number', () {
      // 1 BTC = 30,000,000 CUP. min 100 sats -> 30 CUP, max 1,000,000 -> 300,000.
      final limits = fiatAmountLimits(
        minSats: 100,
        maxSats: 1000000,
        exchangeRate: 30000000,
      );
      expect(limits.minFiat, 30);
      expect(limits.maxFiat, 300000);
      expect(limits.isDisplayable, isTrue);
    });

    test('ceils a non-integer minimum so the shown value is still valid', () {
      // min converts to 30.6 -> 31 (30 would be below the real limit).
      final limits = fiatAmountLimits(
        minSats: 102,
        maxSats: 1000000,
        exchangeRate: 30000000,
      );
      expect(limits.minFiat, 31);
    });

    test('is not displayable when the whole range collapses below 1 fiat', () {
      // Extremely high BTC/fiat parity: max 1,000,000 sats -> 0.5 fiat -> floor 0.
      final limits = fiatAmountLimits(
        minSats: 100,
        maxSats: 1000000,
        exchangeRate: 50,
      );
      expect(limits.maxFiat, 0);
      expect(limits.isDisplayable, isFalse);
    });

    test('returns zeros and is not displayable for a non-positive rate', () {
      final limits = fiatAmountLimits(
        minSats: 100,
        maxSats: 1000000,
        exchangeRate: 0,
      );
      expect(limits.minFiat, 0);
      expect(limits.maxFiat, 0);
      expect(limits.isDisplayable, isFalse);
    });
  });
}
