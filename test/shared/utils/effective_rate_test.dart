import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/shared/utils/effective_rate.dart';

void main() {
  group('EffectiveRate.fiatPerUsd', () {
    test('returns the market cross rate when premium is zero', () {
      // 1 BTC = 1,200 CUP and 1 BTC = 100,000 USD -> 0.012 CUP/USD.
      final rate = EffectiveRate.fiatPerUsd(
        fiatPerBtc: 1200,
        usdPerBtc: 100000,
        premiumPercent: 0,
      );
      expect(rate, closeTo(0.012, 1e-9));
    });

    test('applies a positive premium above the market rate', () {
      final rate = EffectiveRate.fiatPerUsd(
        fiatPerBtc: 1200,
        usdPerBtc: 100000,
        premiumPercent: 30,
      );
      expect(rate, closeTo(0.0156, 1e-9));
    });

    test('applies a discount below the market rate', () {
      final rate = EffectiveRate.fiatPerUsd(
        fiatPerBtc: 1200,
        usdPerBtc: 100000,
        premiumPercent: -30,
      );
      expect(rate, closeTo(0.0084, 1e-9));
    });

    test('returns null when the fiat rate is missing or non positive', () {
      expect(
        EffectiveRate.fiatPerUsd(
          fiatPerBtc: 0,
          usdPerBtc: 100000,
          premiumPercent: 0,
        ),
        isNull,
      );
      expect(
        EffectiveRate.fiatPerUsd(
          fiatPerBtc: -1,
          usdPerBtc: 100000,
          premiumPercent: 0,
        ),
        isNull,
      );
    });

    test('returns null when the usd rate is missing or non positive', () {
      expect(
        EffectiveRate.fiatPerUsd(
          fiatPerBtc: 1200,
          usdPerBtc: 0,
          premiumPercent: 0,
        ),
        isNull,
      );
    });

    test('returns null when a discount removes the whole rate', () {
      expect(
        EffectiveRate.fiatPerUsd(
          fiatPerBtc: 1200,
          usdPerBtc: 100000,
          premiumPercent: -100,
        ),
        isNull,
      );
    });

    test('returns null when any input is not finite', () {
      expect(
        EffectiveRate.fiatPerUsd(
          fiatPerBtc: double.infinity,
          usdPerBtc: 100000,
          premiumPercent: 0,
        ),
        isNull,
      );
      expect(
        EffectiveRate.fiatPerUsd(
          fiatPerBtc: 1200,
          usdPerBtc: double.nan,
          premiumPercent: 0,
        ),
        isNull,
      );
      expect(
        EffectiveRate.fiatPerUsd(
          fiatPerBtc: 1200,
          usdPerBtc: 100000,
          premiumPercent: double.infinity,
        ),
        isNull,
      );
    });
  });

  group('EffectiveRate.format', () {
    test('keeps small positive rates instead of rounding them to zero', () {
      expect(EffectiveRate.format(0.0084, 'en'), '0.0084');
    });

    test('groups large values for readability', () {
      expect(EffectiveRate.format(15000.5, 'en'), '15,000.5');
    });

    test('adapts the decimal separator to the locale', () {
      expect(EffectiveRate.format(15000.5, 'es'), isNot('15,000.5'));
    });
  });
}
