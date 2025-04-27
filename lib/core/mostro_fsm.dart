import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';

/// Finite-State-Machine helper for Mostro order lifecycles.
///
/// This table was generated directly from the authoritative
/// specification sent by the Mostro team.  Only *state–transition →
/// next-state* information is encoded here.  All auxiliary / neutral
/// notifications intentionally map to the **same** state so that
/// `nextStatus` always returns a non-null value.
class MostroFSM {
  MostroFSM._();

  /// Nested map: *currentStatus → { action → nextStatus }*.
  static final Map<Status, Map<Action, Status>> _transitions = {
    // ───────────────────────── MATCHING / TAKING ────────────────────────
    Status.pending: {
      Action.takeSell: Status.waitingBuyerInvoice,
      Action.takeBuy: Status.waitingBuyerInvoice, // invoice presence handled elsewhere
      Action.cancel: Status.canceled,
      Action.disputeInitiatedByYou: Status.dispute,
      Action.disputeInitiatedByPeer: Status.dispute,
    },

    // ───────────────────────── INVOICING ────────────────────────────────
    Status.waitingBuyerInvoice: {
      Action.addInvoice: Status.waitingPayment,
      Action.cancel: Status.canceled,
      Action.disputeInitiatedByYou: Status.dispute,
      Action.disputeInitiatedByPeer: Status.dispute,
    },

    // ───────────────────────── HOLD INVOICE PAYMENT ────────────────────
    Status.waitingPayment: {
      Action.payInvoice: Status.active,
      Action.holdInvoicePaymentAccepted: Status.active,
      Action.holdInvoicePaymentCanceled: Status.canceled,
      Action.cancel: Status.canceled,
      Action.disputeInitiatedByYou: Status.dispute,
      Action.disputeInitiatedByPeer: Status.dispute,
    },

    // ───────────────────────── ACTIVE TRADE ────────────────────────────
    Status.active: {
      Action.fiatSent: Status.fiatSent,
      Action.cooperativeCancelInitiatedByYou: Status.cooperativelyCanceled,
      Action.cooperativeCancelInitiatedByPeer: Status.cooperativelyCanceled,
      Action.cancel: Status.canceled,
      Action.disputeInitiatedByYou: Status.dispute,
      Action.disputeInitiatedByPeer: Status.dispute,
    },

    // ───────────────────────── AFTER FIAT SENT ─────────────────────────
    Status.fiatSent: {
      Action.release: Status.settledHoldInvoice,
      Action.holdInvoicePaymentSettled: Status.settledHoldInvoice,
      Action.cooperativeCancelInitiatedByYou: Status.cooperativelyCanceled,
      Action.cooperativeCancelInitiatedByPeer: Status.cooperativelyCanceled,
      Action.cancel: Status.canceled,
      Action.disputeInitiatedByYou: Status.dispute,
      Action.disputeInitiatedByPeer: Status.dispute,
    },

    // ───────────────────────── AFTER HOLD INVOICE SETTLED ──────────────
    Status.settledHoldInvoice: {
      Action.purchaseCompleted: Status.success,
      Action.disputeInitiatedByYou: Status.dispute,
      Action.disputeInitiatedByPeer: Status.dispute,
    },

    // ───────────────────────── DISPUTE BRANCH ──────────────────────────
    Status.dispute: {
      Action.adminSettle: Status.settledByAdmin,
      Action.adminSettled: Status.settledByAdmin,
      Action.adminCancel: Status.canceledByAdmin,
      Action.adminCanceled: Status.canceledByAdmin,
    },
  };

  /// Returns the next `Status` after applying [action] to [current].
  /// If the action does **not** cause a state change, the same status
  /// is returned.  This makes it easier to call without additional
  /// null-checking.
  static Status nextStatus(Status? current, Action action) {
    // Note: Initial state handled externally — we start from `pending` when the
    // very first `newOrder` message arrives, so there is no `Status.start`
    // entry here.
    // If current is null (unknown), treat as pending so that first transition
    // works for historical messages.
    final safeCurrent = current ?? Status.pending;
    return _transitions[safeCurrent]?[action] ?? safeCurrent;
  }
}
