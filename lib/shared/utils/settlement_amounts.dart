/// Re-derives what a settlement is supposed to cost, from the terms the node
/// signed rather than from the figure it puts in the message.
///
/// The node computes both sides from one order amount and one fee rate, and
/// publishes both inputs where they can be checked independently: the amount
/// in the kind-38383 order event, the rate in the kind-38385 info event. That
/// makes the figure carried in a direct message something the client can
/// re-derive instead of accept.
///
/// The arithmetic mirrors mostrod exactly, because a client that rounds
/// differently would reject settlements that are perfectly correct:
///
/// ```rust
/// // util.rs — get_fee
/// let split_fee = (mostro_settings.fee * amount as f64) / 2.0;
/// split_fee.round() as i64
///
/// // util.rs — show_hold_invoice: what the seller pays
/// let new_amount = order.amount + order.fee;
///
/// // util.rs — set_waiting_invoice_status: what the buyer asks for
/// let buyer_final_amount = order.amount.saturating_sub(order.fee);
/// ```
class SettlementAmounts {
  const SettlementAmounts._();

  /// Bitcoin's supply cap, in satoshis.
  ///
  /// Nothing derived here can exceed it and still be a settlement figure,
  /// whatever the node published to produce it. The same bound guards the
  /// amount parsed out of an invoice.
  static const int maxSats = 21000000 * 100000000;

  /// The node's fee on an order of [amountSats], in satoshis.
  ///
  /// Half the configured rate: each side pays its own half, so neither can
  /// derive the other's figure by halving the total.
  ///
  /// Null when no fee can be derived, which is not the same as a fee of zero
  /// — a node that charges nothing is a term the client can check against,
  /// and a rate it cannot use is not. Checking `isFinite` on the rate alone
  /// does not settle it: the multiplication is where the domain is actually
  /// left. A rate of 1e308 is finite and passes every input check, but the
  /// product overflows to infinity and `round()` throws on it; a rate a
  /// little under that stays finite and `round()` saturates silently at the
  /// int64 ceiling, which is worse — the caller would carry the ceiling into
  /// a derived amount as though the node had really asked for it.
  static int? feeFor({required int amountSats, required double feeRate}) {
    if (amountSats <= 0 || amountSats > maxSats) return null;
    if (!feeRate.isFinite || feeRate < 0) return null;
    if (feeRate == 0) return 0;

    final fee = feeRate * amountSats / 2.0;
    if (!fee.isFinite || fee < 0 || fee > maxSats) return null;
    return fee.round();
  }

  /// What the seller's hold invoice should ask for: the order amount plus
  /// their half of the fee.
  ///
  /// Null when there is nothing to derive from — an order amount that has not
  /// been resolved yet reads as zero, and a client that treated that as a
  /// real figure would expect a settlement of exactly the fee.
  static int? sellerPays({required int amountSats, required double feeRate}) {
    final fee = feeFor(amountSats: amountSats, feeRate: feeRate);
    if (fee == null) return null;

    final total = amountSats + fee;
    return total <= maxSats ? total : null;
  }

  /// What the buyer's payout invoice should ask for: the order amount less
  /// their half of the fee.
  static int? buyerReceives({required int amountSats, required double feeRate}) {
    final fee = feeFor(amountSats: amountSats, feeRate: feeRate);
    if (fee == null) return null;

    final net = amountSats - fee;
    return net > 0 ? net : null;
  }
}
