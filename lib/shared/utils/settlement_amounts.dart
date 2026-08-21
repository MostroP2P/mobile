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

  /// The node's fee on an order of [amountSats], in satoshis.
  ///
  /// Half the configured rate: each side pays its own half, so neither can
  /// derive the other's figure by halving the total.
  static int feeFor({required int amountSats, required double feeRate}) {
    if (amountSats <= 0 || feeRate <= 0 || !feeRate.isFinite) return 0;
    return (feeRate * amountSats / 2.0).round();
  }

  /// What the seller's hold invoice should ask for: the order amount plus
  /// their half of the fee.
  ///
  /// Null when there is nothing to derive from — an order amount that has not
  /// been resolved yet reads as zero, and a client that treated that as a
  /// real figure would expect a settlement of exactly the fee.
  static int? sellerPays({required int amountSats, required double feeRate}) {
    if (amountSats <= 0 || feeRate < 0 || !feeRate.isFinite) return null;
    return amountSats + feeFor(amountSats: amountSats, feeRate: feeRate);
  }

  /// What the buyer's payout invoice should ask for: the order amount less
  /// their half of the fee.
  static int? buyerReceives({required int amountSats, required double feeRate}) {
    if (amountSats <= 0 || feeRate < 0 || !feeRate.isFinite) return null;
    final net = amountSats - feeFor(amountSats: amountSats, feeRate: feeRate);
    return net > 0 ? net : null;
  }
}
