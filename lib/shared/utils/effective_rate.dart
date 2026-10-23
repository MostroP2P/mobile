import 'package:intl/intl.dart';

/// Utility to compute the effective fiat rate of a market price offer after
/// applying the creator's premium/discount.
class EffectiveRate {
  EffectiveRate._();

  /// Returns the effective amount of [currency] per 1 USD for an offer that
  /// trades at [fiatPerBtc] (market rate of the offer's fiat currency against
  /// BTC) with [premiumPercent] applied by the creator.
  ///
  /// A positive [premiumPercent] is a premium, a negative value is a discount.
  /// [usdPerBtc] is the market rate of USD against BTC.
  ///
  /// Returns null when any input is not a finite positive number or when the
  /// resulting cross rate is not a finite positive number.
  static double? fiatPerUsd({
    required double fiatPerBtc,
    required double usdPerBtc,
    required double premiumPercent,
  }) {
    if (!fiatPerBtc.isFinite ||
        !usdPerBtc.isFinite ||
        !premiumPercent.isFinite) {
      return null;
    }
    if (fiatPerBtc <= 0 || usdPerBtc <= 0) return null;
    final effectiveFiatPerBtc = fiatPerBtc * (1 + premiumPercent / 100);
    if (!effectiveFiatPerBtc.isFinite || effectiveFiatPerBtc <= 0) return null;
    final rate = effectiveFiatPerBtc / usdPerBtc;
    if (!rate.isFinite || rate <= 0) return null;
    return rate;
  }

  /// Formats [rate] using the given [locale], keeping up to six fraction
  /// digits so small positive rates are not rounded away, while grouping
  /// large values for readability.
  static String format(double rate, String locale) {
    return NumberFormat('#,##0.######', locale).format(rate);
  }
}
