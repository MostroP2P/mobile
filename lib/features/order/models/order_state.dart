import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/data/enums.dart';

class OrderState {
  final Status status;
  final Action action;
  final Order? order;
  final PaymentRequest? paymentRequest;
  final CantDo? cantDo;
  final Dispute? dispute;
  final Peer? peer;
  final PaymentFailed? paymentFailed;
  final bool fiatWasSent;

  OrderState({
    required this.status,
    required this.action,
    required this.order,
    this.paymentRequest,
    this.cantDo,
    this.dispute,
    this.peer,
    this.paymentFailed,
    this.fiatWasSent = false,
  });

  factory OrderState.fromMostroMessage(MostroMessage message) {
    return OrderState(
      status: message.getPayload<Order>()?.status ?? Status.pending,
      action: message.action,
      order: message.getPayload<Order>(),
      paymentRequest: message.getPayload<PaymentRequest>(),
      cantDo: message.getPayload<CantDo>(),
      dispute: message.getPayload<Dispute>(),
      peer: message.getPayload<Peer>(),
      paymentFailed: message.getPayload<PaymentFailed>(),
    );
  }

  @override
  String toString() =>
      'OrderState(status: $status, action: $action, order: $order, paymentRequest: $paymentRequest, cantDo: $cantDo, dispute: $dispute, peer: $peer, paymentFailed: $paymentFailed, fiatWasSent: $fiatWasSent)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderState &&
          other.status == status &&
          other.action == action &&
          other.order == order &&
          other.paymentRequest == paymentRequest &&
          other.cantDo == cantDo &&
          other.dispute == dispute &&
          other.paymentFailed == paymentFailed &&
          other.peer == peer &&
          other.fiatWasSent == fiatWasSent;

  @override
  int get hashCode => Object.hash(
        status,
        action,
        order,
        paymentRequest,
        cantDo,
        dispute,
        peer,
        paymentFailed,
        fiatWasSent,
      );

  OrderState copyWith({
    Status? status,
    Action? action,
    Order? order,
    PaymentRequest? paymentRequest,
    CantDo? cantDo,
    Dispute? dispute,
    Peer? peer,
    PaymentFailed? paymentFailed,
    bool? fiatWasSent,
  }) {
    return OrderState(
      status: status ?? this.status,
      action: action ?? this.action,
      order: order ?? this.order,
      paymentRequest: paymentRequest ?? this.paymentRequest,
      cantDo: cantDo ?? this.cantDo,
      dispute: dispute ?? this.dispute,
      peer: peer ?? this.peer,
      paymentFailed: paymentFailed ?? this.paymentFailed,
      fiatWasSent: fiatWasSent ?? this.fiatWasSent,
    );
  }

  /// Dispute statuses in which the dispute is over: a resolution has already
  /// been applied and no further admin action is expected for it.
  static const _terminalDisputeStatuses = {
    'resolved',
    'seller-refunded',
    'closed',
  };

  static bool _isAdminDisputeAction(Action action) =>
      action == Action.adminSettled ||
      action == Action.adminSettle ||
      action == Action.adminCanceled ||
      action == Action.adminCancel ||
      action == Action.adminTookDispute ||
      action == Action.adminTakeDispute;

  /// Whether local state corroborates that a dispute exists for this order.
  ///
  /// Evidence is the tracked [Dispute] object and nothing else. In particular
  /// [Status.dispute] does not qualify: any action mapping to that status sets
  /// it without carrying a dispute, so accepting it would let a bare
  /// `dispute` message stand in as the evidence for the `admin-*` message
  /// right behind it.
  ///
  /// The incoming payload does not count either — taking an attacker-supplied
  /// Dispute as its own justification is the vector this guards against. An
  /// already-resolved dispute is not re-resolved, which blocks replaying an
  /// authentic resolution onto a later state.
  bool get _acceptsAdminDisputeAction {
    final localDispute = dispute;
    if (localDispute == null) return false;

    final localDisputeStatus = localDispute.status?.toLowerCase();
    return localDisputeStatus == null ||
        !_terminalDisputeStatuses.contains(localDisputeStatus);
  }

  /// Whether [updateWith] would drop this action for lack of dispute evidence.
  ///
  /// Callers use this to suppress the message's side effects too. A rejected
  /// resolution that still raises a notification or navigates would hand the
  /// attacker the user-visible half of the forgery.
  bool rejectsAdminDisputeAction(Action action) =>
      _isAdminDisputeAction(action) && !_acceptsAdminDisputeAction;

  OrderState updateWith(MostroMessage message) {
    logger.i('Updating OrderState with Action: ${message.action}');

    // Preserve the current state entirely for cantDo messages - they are informational only
    if (message.action == Action.cantDo) {
      return copyWith(cantDo: message.getPayload<CantDo>());
    }

    // An admin resolution only means something as the outcome of a dispute that
    // already exists. Applied unconditionally, a forged or replayed admin-*
    // message flips a live trade to a terminal state and drives the resolution
    // UI, so drop it unless local state corroborates the dispute.
    if (_isAdminDisputeAction(message.action) && !_acceptsAdminDisputeAction) {
      logger.w(
        'Ignoring ${message.action} for order ${message.id}: no dispute '
        'evidence in local state (status: $status, dispute: ${dispute?.status ?? 'none'})',
      );
      return this;
    }

    // Track whether fiat was sent at any point in this order's lifecycle
    final bool newFiatWasSent = fiatWasSent ||
        message.action == Action.fiatSent ||
        message.action == Action.fiatSentOk;

    // Remap generic cooperative cancel actions to semantic variants
    // based on whether fiat was sent before the cancel was initiated
    Action effectiveAction = message.action;
    if (message.action == Action.cooperativeCancelInitiatedByYou) {
      effectiveAction = newFiatWasSent
          ? Action.cooperativeCancelFiatSentByYou
          : Action.cooperativeCancelNoFiatByYou;
      logger.i('Remapped ${message.action} → $effectiveAction (fiatWasSent: $newFiatWasSent)');
    } else if (message.action == Action.cooperativeCancelInitiatedByPeer) {
      effectiveAction = newFiatWasSent
          ? Action.cooperativeCancelFiatSentByPeer
          : Action.cooperativeCancelNoFiatByPeer;
      logger.i('Remapped ${message.action} → $effectiveAction (fiatWasSent: $newFiatWasSent)');
    }

    // Determine the new status based on the action received
    Status newStatus = _getStatusFromAction(
        effectiveAction, message.getPayload<Order>()?.status);

    // DEBUG: Log status mapping
    logger.i('Status mapping: $effectiveAction → $newStatus');

    // Preserve PaymentRequest correctly
    PaymentRequest? newPaymentRequest;
    if (message.payload is PaymentRequest) {
      newPaymentRequest = message.getPayload<PaymentRequest>();
      logger.i('New PaymentRequest found in message');
    } else {
      newPaymentRequest = paymentRequest; // Preserve existing
    }

    Peer? newPeer;
    if (message.payload is Peer &&
        message.getPayload<Peer>()!.publicKey.isNotEmpty) {
      newPeer = message.getPayload<Peer>();
      logger.i('👤 New Peer found in message');
    } else if (message.payload is Order) {
      if (message.getPayload<Order>()!.buyerTradePubkey != null) {
        newPeer =
            Peer(publicKey: message.getPayload<Order>()!.buyerTradePubkey!);
      } else if (message.getPayload<Order>()!.sellerTradePubkey != null) {
        newPeer =
            Peer(publicKey: message.getPayload<Order>()!.sellerTradePubkey!);
      }
      logger.i('👤 New Peer found in message');
    } else {
      newPeer = peer; // Preserve existing
    }

    // Handle dispute status updates based on action.
    // A payload dispute never re-points a tracked dispute at a different id:
    // only the dispute this order already carries can be updated from the wire.
    final localDispute = dispute;
    final payloadDispute = message.getPayload<Dispute>();
    final bool payloadDisputeAccepted = payloadDispute != null &&
        (localDispute == null ||
            payloadDispute.disputeId == localDispute.disputeId);

    if (payloadDispute != null && !payloadDisputeAccepted) {
      logger.w(
        'Ignoring dispute payload ${payloadDispute.disputeId} for order '
        '${message.id}: does not match tracked dispute ${localDispute!.disputeId}',
      );
    }

    Dispute? updatedDispute =
        payloadDisputeAccepted ? payloadDispute : localDispute;

    // If we got a dispute from the message payload, ensure it has the message timestamp
    // This is critical for correct sorting in the dispute list
    if (updatedDispute != null && payloadDisputeAccepted) {
      // Use message timestamp if dispute doesn't have a createdAt or if message has a timestamp
      // Note: Nostr timestamps are in seconds, so convert to milliseconds
      if (message.timestamp != null) {
        final tsMs = message.timestamp! * 1000;
        if (updatedDispute.createdAt == null || 
            updatedDispute.createdAt!.millisecondsSinceEpoch != tsMs) {
          updatedDispute = updatedDispute.copyWith(
            createdAt: DateTime.fromMillisecondsSinceEpoch(tsMs),
          );
          logger.i('Updated dispute ${updatedDispute.disputeId} createdAt from message timestamp: ${updatedDispute.createdAt}');
        }
      }
    }
    
    // Add defensive null check - if both message payload and existing dispute are null,
    // we cannot perform dispute updates
    if (updatedDispute == null && 
        (message.action == Action.adminTookDispute || 
         message.action == Action.adminSettled || 
         message.action == Action.adminCanceled)) {
      logger.w('Cannot update dispute for action ${message.action}: no dispute found in message payload or existing state');
    } else if (message.action == Action.adminTookDispute && updatedDispute != null) {
      // When admin takes dispute, update status to in-progress and set admin info
      // Extract admin pubkey from Peer payload if available
      String? adminPubkey = updatedDispute.adminPubkey;
      if (message.payload is Peer) {
        final peerPayload = message.getPayload<Peer>();
        if (peerPayload != null && peerPayload.publicKey.isNotEmpty) {
          adminPubkey = peerPayload.publicKey;
          logger.i('Extracted admin pubkey from Peer payload: $adminPubkey');
        }
      }
      
      updatedDispute = updatedDispute.copyWith(
        status: 'in-progress',
        adminTookAt: DateTime.now(),
        adminPubkey: adminPubkey,
      );
      logger.i('Updated dispute status to in-progress for adminTookDispute action');
    } else if (message.action == Action.adminSettled && updatedDispute != null) {
      // When admin settles dispute, update status to resolved with settlement info
      updatedDispute = updatedDispute.copyWith(
        status: 'resolved',
        action: 'admin-settled', // Store the resolution type
      );
      logger.i('Updated dispute status to resolved for adminSettled action');
    } else if (message.action == Action.adminCanceled && updatedDispute != null) {
      // When admin cancels order, update dispute status to seller-refunded
      updatedDispute = updatedDispute.copyWith(
        status: 'seller-refunded',
        action: 'admin-canceled', // Store the resolution type
      );
      logger.i('Updated dispute status to seller-refunded for adminCanceled action');
      logger.i('Dispute status updated to: ${updatedDispute.status}');
    }

    // Auto-close dispute when order reaches terminal state by user action
    final disputeAlreadyTerminal = const ['resolved', 'seller-refunded', 'closed']
        .contains(updatedDispute?.status?.toLowerCase());

    if (updatedDispute != null &&
        !disputeAlreadyTerminal &&
        const [Status.success, Status.settledHoldInvoice].contains(newStatus)) {
      updatedDispute = updatedDispute.copyWith(
        status: 'closed',
        action: 'user-completed',
      );
      logger.i('Auto-closed dispute: order completed by users');
    } else if (updatedDispute != null &&
        !disputeAlreadyTerminal &&
        newStatus == Status.canceled &&
        message.action == Action.cooperativeCancelAccepted) {
      updatedDispute = updatedDispute.copyWith(
        status: 'closed',
        action: 'cooperative-cancel',
      );
      logger.i('Auto-closed dispute: cooperative cancellation');
    }

    // Bond acks (3.5) and slash notice (4): their SmallOrder has a null status
    // and a bond-sized amount; don't let it overwrite the tracked trade order.
    final bool isBondPayoutAck =
        message.action == Action.bondInvoiceAccepted ||
            message.action == Action.bondPayoutCompleted ||
            message.action == Action.bondSlashed;

    final newState = copyWith(
      status: newStatus,
      action: effectiveAction,
      order: (message.payload is Order && !isBondPayoutAck)
          ? message.getPayload<Order>()
          : message.payload is PaymentRequest
              ? message.getPayload<PaymentRequest>()!.order
              : order,
      paymentRequest: newPaymentRequest,
      cantDo: message.getPayload<CantDo>() ?? cantDo,
      dispute: updatedDispute,
      peer: newPeer,
      paymentFailed: message.getPayload<PaymentFailed>() ?? paymentFailed,
      fiatWasSent: newFiatWasSent,
    );

    logger.i('New state: ${newState.status} - ${newState.action}');
    logger
        .i('PaymentRequest preserved: ${newState.paymentRequest != null}');

    return newState;
  }

  /// Maps actions to their corresponding statuses based on mostrod DM messages
  Status _getStatusFromAction(Action action, Status? payloadStatus) {
    switch (action) {
      // Actions that should set status to waiting-payment
      case Action.waitingSellerToPay:
      case Action.payInvoice:
        return Status.waitingPayment;

      // Action that should set status to waiting-taker-bond (Phase 1.5 anti-abuse bond)
      case Action.payBondInvoice:
        return Status.waitingTakerBond;

      // Actions that should set status to waiting-buyer-invoice
      case Action.waitingBuyerInvoice:
        return Status.waitingBuyerInvoice;
      
      case Action.addInvoice:
        // If current status is paymentFailed, maintain it for UI consistency
        // Otherwise, transition to waitingBuyerInvoice for normal flow
        if (status == Status.paymentFailed) {
          return Status.paymentFailed;
        }
        return Status.waitingBuyerInvoice;


      // FIX: Cuando alguien toma una orden, debe cambiar el status inmediatamente

      case Action.takeBuy:
        // When buyer takes sell order, seller must wait for buyer invoice
        return Status.waitingBuyerInvoice;

      case Action.takeSell:
        // When seller takes buy order, seller must pay invoice
        return Status.waitingPayment;

      // Actions that should set status to active
      case Action.buyerTookOrder:
      case Action.holdInvoicePaymentAccepted:
      case Action.buyerInvoiceAccepted:
        return Status.active;

      // Actions that should set status to fiat-sent
      case Action.fiatSent:
      case Action.fiatSentOk:
        return Status.fiatSent;

      // Actions that indicate hold invoice settled but buyer payment still in progress
      case Action.released:
      case Action.release:
        return Status.settledHoldInvoice;

      // Actions that should set status to success (completed)
      case Action.purchaseCompleted:
      case Action.rate:
      case Action.rateReceived:
      case Action.holdInvoicePaymentSettled:
        return Status.success;

      // Actions that should set status to canceled
      case Action.canceled:
      case Action.cancel:
      case Action.cooperativeCancelAccepted:
      case Action.holdInvoicePaymentCanceled:
        return Status.canceled;

      // A dispute resolved by cancelation is its own terminal state: it keeps
      // the admin resolution visible to the user and out of the plain-cancel
      // cleanup paths, which are built around Action.canceled.
      case Action.adminCanceled:
      case Action.adminCancel:
        return Status.canceledByAdmin;

      // Actions that should set status to cooperatively canceled (pending cancellation)
      case Action.cooperativeCancelInitiatedByYou:
      case Action.cooperativeCancelInitiatedByPeer:
      case Action.cooperativeCancelNoFiatByYou:
      case Action.cooperativeCancelNoFiatByPeer:
      case Action.cooperativeCancelFiatSentByYou:
      case Action.cooperativeCancelFiatSentByPeer:
        return Status.cooperativelyCanceled;

      // Actions that should set status to dispute
      case Action.disputeInitiatedByYou:
      case Action.disputeInitiatedByPeer:
      case Action.dispute:
      case Action.adminTakeDispute:
      case Action.adminTookDispute:
        return Status.dispute;

      // Actions that should set status to admin settled
      case Action.adminSettle:
      case Action.adminSettled:
        return Status.settledByAdmin;

      // Actions that should set status to payment failed
      case Action.paymentFailed:
        return Status.paymentFailed;

      // Informational actions that should preserve current status
      case Action.rateUser:
      case Action.invoiceUpdated:
      case Action.sendDm:
      case Action.tradePubkey:
      case Action.adminAddSolver:
      case Action.addBondInvoice:
        return payloadStatus ?? status;

      // Bond acks (3.5) and slash notice (4): SmallOrder status is null;
      // keep the order's real status instead of defaulting to pending.
      case Action.bondInvoiceAccepted:
      case Action.bondPayoutCompleted:
      case Action.bondSlashed:
        return status;

      // For actions that include Order payload, use the payload status
      case Action.newOrder:
        return payloadStatus ?? status;


      // For other actions, keep the current status unless payload has a different one
      default:
        return payloadStatus ?? status;
    }
  }

  List<Action> getActions(Role role) {
    return actions[role]?[status]?[action] ?? [];
  }

  static final Map<Role, Map<Status, Map<Action, List<Action>>>> actions = {
    Role.seller: {
      Status.pending: {
        Action.newOrder: [
          Action.cancel,
        ],
        Action.takeBuy: [
          Action.cancel,
        ],
      },
      Status.waitingTakerBond: {
        Action.payBondInvoice: [
          Action.payBondInvoice,
          Action.cancel,
        ],
      },
      Status.waitingPayment: {
        Action.payInvoice: [
          Action.payInvoice,
          Action.cancel,
        ],
        Action.waitingSellerToPay: [
          Action.payInvoice,
          Action.cancel,
        ],
      },
      Status.waitingBuyerInvoice: {
        Action.waitingBuyerInvoice: [
          Action.cancel,
        ],
        Action.addInvoice: [
          Action.cancel,
        ],
        Action.takeBuy: [
          Action.cancel,
        ],
      },
      Status.paymentFailed: {
        Action.paymentFailed: [
          // Only allow payment retry, no cancel or dispute during retrying
          Action.payInvoice,
        ],
      },
      Status.active: {
        Action.buyerTookOrder: [
          Action.cancel,
          Action.dispute,
          Action.sendDm,
        ],
        Action.holdInvoicePaymentAccepted: [
          Action.cancel,
          Action.dispute,
          Action.sendDm,
        ],
        Action.cooperativeCancelInitiatedByPeer: [
          Action.cancel,
          Action.dispute,
          Action.sendDm,
        ],
        Action.cooperativeCancelInitiatedByYou: [
          Action.dispute,
          Action.sendDm,
        ],
      },
      Status.fiatSent: {
        Action.fiatSentOk: [
          Action.release,
          Action.cancel,
          Action.dispute,
          Action.sendDm,
        ],
        Action.cooperativeCancelInitiatedByPeer: [
          Action.release,
          Action.cancel,
          Action.dispute,
          Action.sendDm,
        ],
        Action.cooperativeCancelInitiatedByYou: [
          Action.release,
          Action.dispute,
          Action.sendDm,
        ],
      },
      Status.success: {
        Action.rate: [
          Action.rate,
        ],
        Action.purchaseCompleted: [
          Action.rate,
        ],
        Action.released: [
          Action.rate,
        ],
        Action.holdInvoicePaymentSettled: [
          Action.rate,
        ],
        Action.rateReceived: [],
      },
      Status.canceled: {
        Action.canceled: [],
        Action.adminCanceled: [],
        Action.cooperativeCancelAccepted: [],
      },
      Status.cooperativelyCanceled: {
        // From active: no fiat sent, so no release button for seller
        Action.cooperativeCancelNoFiatByYou: [
          Action.sendDm,
          Action.dispute,
        ],
        Action.cooperativeCancelNoFiatByPeer: [
          Action.sendDm,
          Action.dispute,
          Action.cancel,
        ],
        // From fiat-sent: fiat was sent, seller can release
        Action.cooperativeCancelFiatSentByYou: [
          Action.sendDm,
          Action.dispute,
          Action.release,
        ],
        Action.cooperativeCancelFiatSentByPeer: [
          Action.sendDm,
          Action.dispute,
          Action.cancel,
          Action.release,
        ],
      },
      Status.dispute: {
        Action.disputeInitiatedByYou: [
          Action.sendDm,
          Action.cancel,
          Action.release,
        ],
        Action.disputeInitiatedByPeer: [
          Action.sendDm,
          Action.cancel,
          Action.release,
        ],
        Action.adminTookDispute: [
          Action.sendDm,
          Action.cancel,
          Action.release,
        ],
      },
      Status.settledHoldInvoice: {
        Action.addInvoice: [
          Action.addInvoice,
          Action.cancel,
        ],
      },
    },
    Role.buyer: {
      Status.pending: {
        Action.newOrder: [
          Action.cancel,
        ],
        Action.takeSell: [
          Action.cancel,
        ],
      },
      Status.waitingTakerBond: {
        Action.payBondInvoice: [
          Action.payBondInvoice,
          Action.cancel,
        ],
      },
      Status.waitingPayment: {
        Action.waitingSellerToPay: [
          Action.cancel,
        ],
        Action.takeSell: [
          Action.cancel,
        ],
      },
      Status.waitingBuyerInvoice: {
        Action.addInvoice: [
          Action.addInvoice,
          Action.cancel,
        ],
        Action.waitingBuyerInvoice: [
          Action.cancel,
        ],
      },
      Status.paymentFailed: {
        Action.addInvoice: [
          // Only allow add invoice, no cancel or dispute during retrying
          Action.addInvoice,
        ],
        Action.paymentFailed: [],
      },
      Status.active: {
        Action.holdInvoicePaymentAccepted: [
          Action.fiatSent,
          Action.cancel,
          Action.dispute,
          Action.sendDm,
        ],
        Action.buyerTookOrder: [
          Action.cancel,
          Action.dispute,
          Action.sendDm,
        ],
        Action.cooperativeCancelInitiatedByPeer: [
          Action.cancel,
          Action.dispute,
          Action.sendDm,
        ],
        Action.cooperativeCancelInitiatedByYou: [
          Action.dispute,
          Action.sendDm,
        ],
      },
      Status.fiatSent: {
        Action.fiatSentOk: [
          Action.cancel,
          Action.dispute,
          Action.sendDm,
        ],
        Action.cooperativeCancelInitiatedByPeer: [
          Action.cancel,
          Action.dispute,
          Action.sendDm,
        ],
        Action.cooperativeCancelInitiatedByYou: [
          Action.dispute,
          Action.sendDm,
        ],
      },
      Status.success: {
        Action.rate: [
          Action.rate,
        ],
        Action.purchaseCompleted: [
          Action.rate,
        ],
        Action.released: [
          Action.rate,
        ],
        Action.rateReceived: [],
      },
      Status.canceled: {
        Action.canceled: [],
        Action.adminCanceled: [],
        Action.cooperativeCancelAccepted: [],
      },
      Status.cooperativelyCanceled: {
        // From active: no fiat sent, buyer can still send fiat to complete trade
        Action.cooperativeCancelNoFiatByYou: [
          Action.sendDm,
          Action.dispute,
        ],
        Action.cooperativeCancelNoFiatByPeer: [
          Action.sendDm,
          Action.dispute,
          Action.cancel,
          Action.fiatSent,
        ],
        // From fiat-sent: fiat already sent, no fiatSent button needed
        Action.cooperativeCancelFiatSentByYou: [
          Action.sendDm,
          Action.dispute,
        ],
        Action.cooperativeCancelFiatSentByPeer: [
          Action.sendDm,
          Action.dispute,
          Action.cancel,
        ],
      },
      Status.dispute: {
        Action.disputeInitiatedByYou: [
          Action.sendDm,
          Action.cancel,
        ],
        Action.disputeInitiatedByPeer: [
          Action.sendDm,
          Action.cancel,
        ],
        Action.adminTookDispute: [
          Action.sendDm,
          Action.cancel,
        ],
      },
      Status.settledHoldInvoice: {
        Action.addInvoice: [
          Action.addInvoice,
          Action.cancel,
        ],
      },
    },
  };
}
