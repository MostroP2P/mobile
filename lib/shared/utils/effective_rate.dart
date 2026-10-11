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
  /// Returns null when any input makes the cross rate meaningless (rates not
  /// available, zero or negative).
  static double? fiatPerUsd({
    required double fiatPerBtc,
    required double usdPerBtc,
    required double premiumPercent,
  }) {
    if (fiatPerBtc <= 0 || usdPerBtc <= 0) return null;
    final effectiveFiatPerBtc = fiatPerBtc * (1 + premiumPercent / 100);
    if (effectiveFiatPerBtc <= 0) return null;
    final rate = effectiveFiatPerBtc / usdPerBtc;
    return rate > 0 ? rate : null;
  }
}
