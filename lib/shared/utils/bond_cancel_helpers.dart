import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models.dart';

/// Pure decision helpers for the bond-cancel session lifecycle. The daemon
/// only sends a `bond-slashed` notice after a *waiting-timeout slash*, never
/// after a voluntary cancel (which returns the taker's bond). These functions
/// encode when the session deletion must wait for that notice and how to
/// reconcile a session whose in-memory grace timer was lost on restart.

/// Whether deletion of a `canceled` order's session should be deferred to wait
/// for a trailing `bond-slashed` notice. Deferral is needed only for a bonded
/// order that the user did NOT cancel itself: a voluntary cancel returns the
/// bond (no slash, no notice), and a non-bonded order is never slashed.
bool shouldDeferBondCancelDeletion({
  required bool userInitiated,
  required bool hadBond,
}) =>
    !userInitiated && hadBond;

/// What to do with a session whose order rebuilt as `canceled` on startup,
/// when the in-memory grace timer may have been lost by an app close.
enum BondCancelReconcileAction {
  /// Leave it alone (no session, no bond, or a live timer already owns it).
  none,

  /// Delete now — the grace window already elapsed or the notice arrived.
  deleteNow,

  /// Re-arm the grace timer — the window has not elapsed, a trailing
  /// `bond-slashed` may still be received after a quick restart.
  rearm,
}

/// Decides the reconcile action from the canceled order's persisted facts.
/// `latestCanceledTimestamp` is the newest `canceled` message time in ms (0 if
/// none). The live-timer guard is handled by the caller before this is reached.
BondCancelReconcileAction reconcileBondCancelAction({
  required bool sessionExists,
  required bool hadBond,
  required bool bondSlashedReceived,
  required int latestCanceledTimestamp,
  required int nowMs,
  required int graceWindowMs,
}) {
  // Non-bonded cancels are deleted immediately by the live handler; a missing
  // session means cleanup already happened.
  if (!sessionExists || !hadBond) return BondCancelReconcileAction.none;

  final elapsed = nowMs - latestCanceledTimestamp;
  if (bondSlashedReceived ||
      latestCanceledTimestamp == 0 ||
      elapsed >= graceWindowMs) {
    return BondCancelReconcileAction.deleteNow;
  }
  return BondCancelReconcileAction.rearm;
}

/// Newest `canceled` message timestamp in ms for the order, or 0 if none.
int latestCanceledTimestamp(List<MostroMessage> messages) => messages
    .where((m) => m.action == Action.canceled)
    .map((m) => m.timestamp ?? 0)
    .fold<int>(0, (a, b) => a > b ? a : b);
