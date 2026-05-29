import 'dart:math';

/// Pure helpers to express a Mostro node's sats order limits in the fiat
/// currency the user types in. The node enforces a hard min/max in sats, but
/// the create-order field only accepts whole fiat numbers >= 1, so the sats
/// bounds are converted back to fiat and rounded to the nearest *enterable and
/// valid* integer.
class FiatAmountLimits {
  final int minFiat;
  final int maxFiat;

  const FiatAmountLimits({required this.minFiat, required this.maxFiat});

  /// Whether the fiat range can be shown. False when the whole valid range
  /// collapses below 1 unit of fiat (no whole number is enterable) or the rate
  /// was unavailable; callers should then fall back to the raw sats limits.
  bool get isDisplayable => minFiat >= 1 && maxFiat >= minFiat;
}

/// Sats per BTC.
const int _satsPerBtc = 100000000;

/// Converts the node's sats limits to displayable whole-fiat bounds using the
/// current exchange rate (BTC price in the selected fiat). The minimum rounds
/// up and the maximum rounds down, so every value in the shown range stays
/// >= the real min and <= the real max. The minimum is floored at 1 because
/// the field rejects 0 and decimals.
FiatAmountLimits fiatAmountLimits({
  required int minSats,
  required int maxSats,
  required double exchangeRate,
}) {
  if (exchangeRate <= 0) {
    return const FiatAmountLimits(minFiat: 0, maxFiat: 0);
  }
  final minFiat = max(1, (minSats / _satsPerBtc * exchangeRate).ceil());
  final maxFiat = (maxSats / _satsPerBtc * exchangeRate).floor();
  return FiatAmountLimits(minFiat: minFiat, maxFiat: maxFiat);
}
