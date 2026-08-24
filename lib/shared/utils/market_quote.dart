import 'package:mostro_mobile/data/models/enums/role.dart';

/// Re-prices a market-price order from an outside rate, so a settlement the
/// user never saw a figure for is held to something the node did not choose.
///
/// A fixed-amount order states its sats up front; the take screen shows it and
/// the client pins it. A market-price order states only fiat and a premium,
/// and the node resolves the sats itself at take time — the figure that later
/// appears on the invoice screen is the first the user sees of it, and
/// checking it against the node's own order event only asks the node whether
/// it agrees with itself.
///
/// The arithmetic mirrors mostrod so an honest quote lands on the same figure:
///
/// ```rust
/// // util.rs — get_market_quote
/// let mut sats = (*fiat_amount as f64 / price) * 100_000_000_f64;
/// if premium != 0 {
///     sats -= (premium as f64) / 100_f64 * sats;
/// }
/// Ok(sats as i64)
/// ```
///
/// A positive premium *lowers* the sats, which is the direction that reads
/// backwards: the premium is what the maker charges over the market, so the
/// counterparty gets fewer sats for the same fiat.
class MarketQuote {
  const MarketQuote._();

  static const int _satsPerBtc = 100000000;

  /// Bitcoin's supply cap, as the ceiling any real quote has to sit under.
  static const int _maxSats = 21000000 * _satsPerBtc;

  /// How far a settlement may sit from the quote before it is worth saying so.
  ///
  /// Wide enough to absorb what honestly moves the two apart — a different
  /// rate aggregate, and the minutes between the node pricing the take and
  /// the user reaching the settlement screen — and still narrow enough to
  /// catch a skim, which has to be worth taking to be worth doing.
  static const double tolerance = 0.05;

  /// What [fiatAmount] is worth in satoshis at [fiatPerBtc], after [premium].
  ///
  /// Null when an input cannot produce a figure worth comparing against.
  static int? satsFor({
    required int fiatAmount,
    required double fiatPerBtc,
    required double premium,
  }) {
    if (fiatAmount <= 0) return null;
    if (fiatPerBtc <= 0 || !fiatPerBtc.isFinite) return null;
    if (!premium.isFinite) return null;

    var sats = (fiatAmount / fiatPerBtc) * _satsPerBtc;
    if (premium != 0) {
      sats -= (premium / 100.0) * sats;
    }

    if (!sats.isFinite || sats < 1 || sats > _maxSats) return null;
    // mostrod truncates on the cast to i64; rounding would put the client a
    // satoshi off an otherwise exact quote.
    return sats.truncate();
  }

  /// How far [settledSats] sits from [quotedSats], as a fraction of the quote.
  ///
  /// Null when there is no quote to be a fraction of.
  static double? deviation({
    required int quotedSats,
    required int settledSats,
  }) {
    if (quotedSats <= 0) return null;
    return (settledSats - quotedSats).abs() / quotedSats;
  }
}

/// What re-pricing an order against an outside rate turned up.
class MarketCheck {
  /// What the outside rate says the order is worth, in satoshis.
  final int quotedSats;

  /// What the order actually settles at, in satoshis.
  final int settledSats;

  /// How far the two are apart, as a fraction of [quotedSats].
  final double deviation;

  const MarketCheck({
    required this.quotedSats,
    required this.settledSats,
    required this.deviation,
  });

  /// Whether the gap is wide enough to put in front of the user.
  bool get isOffMarket => deviation > MarketQuote.tolerance;

  /// Whether the order settles for fewer sats than the outside rate says it
  /// should.
  bool get isBelowMarket => settledSats < quotedSats;

  /// Whether the gap runs against the user holding [role].
  ///
  /// Which direction hurts depends on the side. A seller gives up sats for
  /// fiat, so a settlement above the quote takes more from them than the
  /// trade was for; a buyer receives sats for fiat, so one below the quote
  /// hands them less. The other direction is a gap in the user's favour,
  /// which is worth mentioning and not worth stopping.
  bool isAdverseTo(Role role) =>
      role == Role.seller ? !isBelowMarket : isBelowMarket;

  /// Re-prices [settledSats] against [fiatPerBtc], or returns null when there
  /// is not enough to compare.
  static MarketCheck? of({
    required int settledSats,
    required int fiatAmount,
    required double fiatPerBtc,
    required double premium,
  }) {
    if (settledSats <= 0) return null;

    final quotedSats = MarketQuote.satsFor(
      fiatAmount: fiatAmount,
      fiatPerBtc: fiatPerBtc,
      premium: premium,
    );
    if (quotedSats == null) return null;

    final deviation = MarketQuote.deviation(
      quotedSats: quotedSats,
      settledSats: settledSats,
    );
    if (deviation == null) return null;

    return MarketCheck(
      quotedSats: quotedSats,
      settledSats: settledSats,
      deviation: deviation,
    );
  }
}
