import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/enums/role.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';

/// Finite-State-Machine helper for Mostro order lifecycles.
/// Only *state–transition → next-state* information is encoded here.
/// All auxiliary / neutral notifications intentionally map to
/// the **same** state so that `nextStatus` always returns a non-null value.
class MostroFSM {
  /// Nested map: *currentStatus → { role → { action → nextStatus } }*.
  static final Map<Status, Map<Role, Map<Action, Status>>> _transitions = {
    // ───────────────────────── MATCHING / TAKING ────────────────────────
    Status.pending: {
      Role.buyer: {
        Action.takeSell: Status.waitingBuyerInvoice,
        Action.cancel: Status.canceled,
      },
      Role.seller: {
        Action.takeBuy: Status.waitingPayment,
        Action.cancel: Status.canceled,
      },
      Role.admin: {},
    },
    // ───────────────────────── INVOICING ────────────────────────────────
    Status.waitingBuyerInvoice: {
      Role.buyer: {
        Action.addInvoice: Status.waitingPayment,
        Action.cancel: Status.canceled,
      },
      Role.seller: {},
      Role.admin: {},
    },
    // ───────────────────────── HOLD INVOICE PAYMENT ────────────────────
    Status.waitingPayment: {
      Role.seller: {
        Action.payInvoice: Status.active,
        Action.cancel: Status.canceled,
      },
      Role.buyer: {},
      Role.admin: {},
    },
    // ───────────────────────── ACTIVE ────────────────────────────
    Status.active: {
      Role.buyer: {
        Action.fiatSent: Status.fiatSent,
        Action.cancel: Status.canceled,
        Action.disputeInitiatedByYou: Status.dispute,
      },
      Role.seller: {
        Action.cancel: Status.canceled,
        Action.disputeInitiatedByYou: Status.dispute,
      },
      Role.admin: {},
    },
    // ───────────────────────── FIAT SENT ─────────────────────────
    Status.fiatSent: {
      Role.buyer: {
        Action.holdInvoicePaymentSettled: Status.settledHoldInvoice,
        Action.disputeInitiatedByYou: Status.dispute,
      },
      Role.seller: {
        Action.release: Status.settledHoldInvoice,
        Action.cancel: Status.canceled,
        Action.disputeInitiatedByYou: Status.dispute,
      },
      Role.admin: {},
    },
    // ───────────────────────── SETTLED HOLD INVOICE ────────────────────
    Status.settledHoldInvoice: {
      Role.buyer: {
        // Both parties wait for completion or admin intervention
      },
      Role.seller: {
        // Both parties wait for completion or admin intervention
      },
      Role.admin: {
        // Admin can intervene if needed
      },
    },
    // ───────────────────────── SUCCESS ────────────────────────────────
    Status.success: {
      Role.buyer: {
        Action.rate: Status.success,
      },
      Role.seller: {
        Action.rate: Status.success,
      },
      Role.admin: {
        // Admin can rate or intervene if protocol allows
      },
    },
    // ───────────────────────── DISPUTE ────────────────────────────────
    Status.dispute: {
      Role.buyer: {
        // Wait for admin to resolve
      },
      Role.seller: {
        // Wait for admin to resolve
      },
      Role.admin: {
        Action.adminSettle: Status.settledByAdmin,
        Action.adminSettled: Status.settledByAdmin,
        Action.adminCancel: Status.canceledByAdmin,
        Action.adminCanceled: Status.canceledByAdmin,
      },
    },
    // ───────────────────────── CANCELED ────────────────────────────────
    Status.canceled: {
      Role.buyer: {},
      Role.seller: {},
      Role.admin: {},
    },
  };

  /// Returns the next status for a given current status, role, and action.
  static Status? nextStatus(Status current, Role role, Action action) {
    return _transitions[current]?[role]?[action];
  }

  /// Get all possible actions for a status and role
  static List<Action> possibleActions(Status current, Role role) {
    return _transitions[current]?[role]?.keys.toList() ?? [];
  }
}
