/// Why a bond the node asked for cannot be reconciled with what it advertised.
enum BondProblem {
  /// The node never advertised that it charges bonds, so there is no policy
  /// this request could be following.
  notAdvertised,

  /// The bond is smaller than the advertised floor, which the node's own
  /// computation can never produce.
  belowFloor,

  /// The bond is not the figure the advertised percentage yields for this
  /// order.
  wrongAmount,
}

/// Holds a bond request against the policy the node published.
///
/// The bond parameters live in the node's kind-38385 info event, and the node
/// sizes every bond from them:
///
/// ```rust
/// // app/bond/math.rs — compute_bond_amount
/// bond_amount = max(round(amount_pct * order_amount_sats), base_amount_sats)
/// ```
///
/// Nothing gated an inbound `pay-bond-invoice` on any of it, so the figure was
/// whatever the message said — a small trade could be met with an arbitrarily
/// large bond.
class BondAmounts {
  const BondAmounts._();

  /// The bond the node's own formula yields for an order of [orderAmountSats].
  ///
  /// Mirrors the daemon: the percentage is rounded to the nearest satoshi and
  /// the floor is a floor, so a tiny order never yields a trivial bond. An
  /// unresolved order amount yields the floor, which is what the daemon
  /// returns for a non-positive notional.
  static int expectedFor({
    required int orderAmountSats,
    required double amountPct,
    required int baseAmountSats,
  }) {
    final base = baseAmountSats > 0 ? baseAmountSats : 0;
    if (orderAmountSats <= 0 || amountPct <= 0 || !amountPct.isFinite) {
      return base;
    }

    final pct = (orderAmountSats * amountPct).round();
    return pct > base ? pct : base;
  }

  /// What stops [requestedSats] from being a bond this node would have asked
  /// for, or null when nothing does.
  ///
  /// [orderAmountSats] is the sats this trade is for, or null when the client
  /// does not have it — a market-priced range order is sized from the taker's
  /// own quote, which the node computes and the client never sees. Only the
  /// floor can be checked then, and that is said rather than assumed: the
  /// alternative is refusing bonds that are perfectly correct.
  static BondProblem? problemWith({
    required int? requestedSats,
    required int? orderAmountSats,
    required bool advertised,
    required double? amountPct,
    required int? baseAmountSats,
  }) {
    if (!advertised || amountPct == null || baseAmountSats == null) {
      return BondProblem.notAdvertised;
    }
    if (requestedSats == null || requestedSats <= 0) {
      return BondProblem.wrongAmount;
    }

    final floor = baseAmountSats > 0 ? baseAmountSats : 0;
    if (requestedSats < floor) return BondProblem.belowFloor;

    if (orderAmountSats == null || orderAmountSats <= 0) return null;

    final expected = expectedFor(
      orderAmountSats: orderAmountSats,
      amountPct: amountPct,
      baseAmountSats: baseAmountSats,
    );
    return requestedSats == expected ? null : BondProblem.wrongAmount;
  }
}
