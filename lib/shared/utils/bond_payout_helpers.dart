import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models.dart';

enum BondPayoutPhase {
  /// No bond payout flow for this order.
  none,

  /// Latest bond-related message is an inbound `BondPayoutRequest`
  /// awaiting the user's `PaymentRequest` reply (or a retry after a
  /// previous acknowledgement).
  pending,

  /// Mostro acknowledged receipt of the user's invoice via
  /// `bond-invoice-accepted`. Payment is in progress; the user must not
  /// resubmit until either a new `add-bond-invoice` arrives (Failed-state
  /// resurrection) or `bond-payout-completed` confirms terminal success.
  acknowledged,

  /// Mostro confirmed `send_payment` succeeded via `bond-payout-completed`.
  /// The bond claim is closed; no further submissions are expected.
  completed,
}

DateTime bondClaimDeadline(int slashedAt, int claimWindowDays) {
  return DateTime.fromMillisecondsSinceEpoch(
    (slashedAt + claimWindowDays * 86400) * 1000,
    isUtc: true,
  ).toLocal();
}

bool isBondClaimExpired(int slashedAt, int claimWindowDays) {
  return DateTime.now().isAfter(bondClaimDeadline(slashedAt, claimWindowDays));
}

/// Latest inbound `BondPayoutRequest` for the order, picked by timestamp
/// regardless of input ordering. `null` when the most recent
/// `add-bond-invoice` is an outbound `PaymentRequest` reply or absent.
BondPayoutRequest? latestBondPayoutRequest(List<MostroMessage> messages) {
  final sorted = [...messages]..sort(
      (a, b) => (b.timestamp ?? 0).compareTo(a.timestamp ?? 0),
    );
  for (final msg in sorted) {
    if (msg.action != Action.addBondInvoice) continue;
    final payload = msg.payload;
    if (payload is BondPayoutRequest) return payload;
    if (payload is PaymentRequest) return null;
  }
  return null;
}

/// Determines the current phase of the bond payout flow based on the
/// timestamp-ordered history. Only messages relevant to the bond flow
/// (`addBondInvoice`, `bondInvoiceAccepted`, `bondPayoutCompleted`) are
/// considered. The latest one decides the phase.
BondPayoutPhase bondPayoutPhase(List<MostroMessage> messages) {
  final relevant = messages.where((m) =>
      m.action == Action.addBondInvoice ||
      m.action == Action.bondInvoiceAccepted ||
      m.action == Action.bondPayoutCompleted);
  if (relevant.isEmpty) return BondPayoutPhase.none;

  final sorted = [...relevant]..sort(
      (a, b) => (b.timestamp ?? 0).compareTo(a.timestamp ?? 0),
    );

  for (final msg in sorted) {
    switch (msg.action) {
      case Action.bondPayoutCompleted:
        return BondPayoutPhase.completed;
      case Action.bondInvoiceAccepted:
        return BondPayoutPhase.acknowledged;
      case Action.addBondInvoice:
        if (msg.payload is BondPayoutRequest) {
          return BondPayoutPhase.pending;
        }
        // Outbound PaymentRequest reply: keep looking for the next
        // bond-flow message that defines a real phase.
        continue;
      default:
        continue;
    }
  }
  return BondPayoutPhase.none;
}

/// True when the bond claim is in `pending` phase and the claim window has
/// not expired. Used to gate the CLAIM button and the "PAYOUT PENDING"
/// badge.
bool hasPendingBondClaim(
  List<MostroMessage> messages,
  int claimWindowDays,
) {
  if (bondPayoutPhase(messages) != BondPayoutPhase.pending) return false;
  final request = latestBondPayoutRequest(messages);
  if (request == null) return false;
  return !isBondClaimExpired(request.slashedAt, claimWindowDays);
}
