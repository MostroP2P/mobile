import 'package:logger/logger.dart';
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
  final _logger = Logger();

  OrderState({
    required this.status,
    required this.action,
    required this.order,
    this.paymentRequest,
    this.cantDo,
    this.dispute,
    this.peer,
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
    );
  }

  @override
  String toString() =>
      'OrderState(status: $status, action: $action, order: $order, paymentRequest: $paymentRequest, cantDo: $cantDo, dispute: $dispute, peer: $peer)';

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
          other.peer == peer;

  @override
  int get hashCode => Object.hash(
        status,
        action,
        order,
        paymentRequest,
        cantDo,
        dispute,
        peer,
      );

  OrderState copyWith({
    Status? status,
    Action? action,
    Order? order,
    PaymentRequest? paymentRequest,
    CantDo? cantDo,
    Dispute? dispute,
    Peer? peer,
  }) {
    return OrderState(
      status: status ?? this.status,
      action: action ?? this.action,
      order: order ?? this.order,
      paymentRequest: paymentRequest ?? this.paymentRequest,
      cantDo: cantDo ?? this.cantDo,
      dispute: dispute ?? this.dispute,
      peer: peer ?? this.peer,
    );
  }

  OrderState updateWith(MostroMessage message) {
    _logger.i('🔄 Updating OrderState with Action: ${message.action}');

    // Preserve the current state entirely for cantDo messages - they are informational only
    if (message.action == Action.cantDo) {
      return copyWith(cantDo: message.getPayload<CantDo>());
    }

    // Determine the new status based on the action received
    Status newStatus = _getStatusFromAction(
        message.action, message.getPayload<Order>()?.status);

    // 🔍 DEBUG: Log status mapping
    _logger.i('📊 Status mapping: ${message.action} → $newStatus');

    // Preserve PaymentRequest correctly
    PaymentRequest? newPaymentRequest;
    if (message.payload is PaymentRequest) {
      newPaymentRequest = message.getPayload<PaymentRequest>();
      _logger.i('💳 New PaymentRequest found in message');
    } else {
      newPaymentRequest = paymentRequest; // Preserve existing
    }

    Peer? newPeer;
    if (message.payload is Peer &&
        message.getPayload<Peer>()!.publicKey.isNotEmpty) {
      newPeer = message.getPayload<Peer>();
      _logger.i('👤 New Peer found in message');
    } else if (message.payload is Order) {
      if (message.getPayload<Order>()!.buyerTradePubkey != null) {
        newPeer =
            Peer(publicKey: message.getPayload<Order>()!.buyerTradePubkey!);
      } else if (message.getPayload<Order>()!.sellerTradePubkey != null) {
        newPeer =
            Peer(publicKey: message.getPayload<Order>()!.sellerTradePubkey!);
      }
      _logger.i('👤 New Peer found in message');
    } else {
      newPeer = peer; // Preserve existing
    }

    final newState = copyWith(
      status: newStatus,
      action: message.action,
      order: message.payload is Order
          ? message.getPayload<Order>()
          : message.payload is PaymentRequest
              ? message.getPayload<PaymentRequest>()!.order
              : order,
      paymentRequest: newPaymentRequest,
      cantDo: message.getPayload<CantDo>() ?? cantDo,
      dispute: message.getPayload<Dispute>() ?? dispute,
      peer: newPeer,
    );

    return newState;
  }

  /// Maps actions to their corresponding statuses based on mostrod DM messages
  Status _getStatusFromAction(Action action, Status? payloadStatus) {
    switch (action) {
      // Actions that should set status to waiting-payment
      case Action.waitingSellerToPay:
      case Action.payInvoice:
        return Status.waitingPayment;

      // Actions that should set status to waiting-buyer-invoice
      case Action.waitingBuyerInvoice:
      case Action.addInvoice:
        return Status.waitingBuyerInvoice;

      // ✅ FIX: Cuando alguien toma una orden, debe cambiar el status inmediatamente
      case Action.takeBuy:
        // Cuando buyer toma sell order, seller debe esperar buyer invoice
        return Status.waitingBuyerInvoice;

      case Action.takeSell:
        // Cuando seller toma buy order, seller debe pagar invoice
        return Status.waitingPayment;

      // Actions that should set status to active
      case Action.buyerTookOrder:
      case Action.holdInvoicePaymentAccepted:
      case Action.holdInvoicePaymentSettled:
      case Action.buyerInvoiceAccepted:
        return Status.active;

      // Actions that should set status to fiat-sent
      case Action.fiatSent:
      case Action.fiatSentOk:
        return Status.fiatSent;

      // Actions that should set status to success (completed)
      case Action.purchaseCompleted:
      case Action.released:
      case Action.release:
      case Action.rate:
      case Action.rateReceived:
        return Status.success;

      // Actions that should set status to canceled
      case Action.canceled:
      case Action.cancel:
      case Action.adminCanceled:
      case Action.adminCancel:
      case Action.cooperativeCancelAccepted:
      case Action.holdInvoicePaymentCanceled:
        return Status.canceled;

      // Actions that should set status to cooperatively canceled (pending cancellation)
      case Action.cooperativeCancelInitiatedByYou:
      case Action.cooperativeCancelInitiatedByPeer:
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

      // Informational actions that should preserve current status
      case Action.rateUser:
      case Action.paymentFailed:
      case Action.invoiceUpdated:
      case Action.sendDm:
      case Action.tradePubkey:
      case Action.adminAddSolver:
        return payloadStatus ?? status;

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
        Action.holdInvoicePaymentSettled: [
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
        Action.rateReceived: [],
      },
      Status.canceled: {
        Action.canceled: [],
        Action.adminCanceled: [],
        Action.cooperativeCancelAccepted: [],
      },
      Status.cooperativelyCanceled: {
        Action.cooperativeCancelInitiatedByYou: [
          Action.sendDm,
          Action.dispute,
          Action.release,
        ],
        Action.cooperativeCancelInitiatedByPeer: [
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
      Status.active: {
        Action.holdInvoicePaymentAccepted: [
          Action.fiatSent,
          Action.cancel,
          Action.dispute,
          Action.sendDm,
        ],
        Action.holdInvoicePaymentSettled: [
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
        Action.cooperativeCancelInitiatedByYou: [
          Action.sendDm,
          Action.dispute,
        ],
        Action.cooperativeCancelInitiatedByPeer: [
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
      },
    },
  };
}
