import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models.dart';

/// Pure helpers to classify why a bond was slashed, inferred from an order's
/// message history.
///
/// The daemon sends the same `bond-slashed` notice (identical payload, no
/// reason field) for both a waiting-state timeout slash and a solver-directed
/// dispute slash, so the client infers the cause from context. The two causes
/// are mutually exclusive: a timeout slash only happens in a waiting state,
/// before any dispute; once an order is disputed, the only slash path is the
/// admin resolution. So the presence of any dispute/admin action in the history
/// unambiguously marks a dispute slash.
enum BondSlashCause { timeout, dispute }

/// Actions that prove the order went through a dispute / admin resolution.
const _disputeActions = {
  Action.disputeInitiatedByYou,
  Action.disputeInitiatedByPeer,
  Action.adminSettled,
  Action.adminCanceled,
};

/// Infers the cause of a bond slash from the order's [messages]. Returns
/// [BondSlashCause.dispute] when the history shows a dispute/admin resolution,
/// otherwise [BondSlashCause.timeout] (also the default for an empty history).
BondSlashCause bondSlashCause(List<MostroMessage> messages) {
  final disputed = messages.any((m) => _disputeActions.contains(m.action));
  return disputed ? BondSlashCause.dispute : BondSlashCause.timeout;
}

/// Whether the order's bond was slashed (a `bond-slashed` notice exists in the
/// history). Drives the dispute-only notice shown in order details.
bool orderBondWasSlashed(List<MostroMessage> messages) =>
    messages.any((m) => m.action == Action.bondSlashed);

/// Whether a bond slash is a timeout slash: a plain `canceled` is present AND no
/// dispute/admin markers are. Anything else (incl. a conflicting history) returns
/// false, keeping the session — the safe default for an irreversible delete.
bool bondSlashIsTimeout(List<MostroMessage> messages) =>
    messages.any((m) => m.action == Action.canceled) &&
    bondSlashCause(messages) == BondSlashCause.timeout;

/// The slashed bond amount carried by the order's `bond-slashed` notice, or
/// null when there is no such message or its payload is missing.
int? slashedBondAmount(List<MostroMessage> messages) {
  for (final m in messages) {
    if (m.action == Action.bondSlashed) {
      final order = m.getPayload<Order>();
      if (order != null) return order.amount;
    }
  }
  return null;
}
