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
    _logger.i('Updating OrderState Action: ${message.action}');
    
    // Preserve the current state entirely for cantDo messages - they are informational only
    if (message.action == Action.cantDo) {
      return this;
    }
    
    // Determine the new status based on the action received
    Status newStatus = _getStatusFromAction(message.action, message.getPayload<Order>()?.status);
    
    return copyWith(
      status: newStatus,
      action: message.action,
      order: message.payload is Order
          ? message.getPayload<Order>()
          : message.payload is PaymentRequest
              ? message.getPayload<PaymentRequest>()!.order
              : order,
      paymentRequest: message.getPayload<PaymentRequest>() ?? paymentRequest,
      cantDo: message.getPayload<CantDo>() ?? cantDo,
      dispute: message.getPayload<Dispute>() ?? dispute,
      peer: message.getPayload<Peer>() ?? peer,
    );
  }

  /// Maps actions to their corresponding statuses based on mostrod DM messages
  Status _getStatusFromAction(Action action, Status? payloadStatus) {
    switch (action) {
      // Actions that should set status to waiting-payment
      case Action.waitingSellerToPay:
        return Status.waitingPayment;
      
      // Actions that should set status to waiting-buyer-invoice
      case Action.waitingBuyerInvoice:
      case Action.addInvoice:
        return Status.waitingBuyerInvoice;
      
      // Actions that should set status to active
      case Action.buyerTookOrder:
      case Action.holdInvoicePaymentAccepted:
      case Action.holdInvoicePaymentSettled:
        return Status.active;
      
      // Actions that should set status to fiat-sent
      case Action.fiatSent:
      case Action.fiatSentOk:
        return Status.fiatSent;
      
      // Actions that should set status to success (completed)
      case Action.purchaseCompleted:
      case Action.released:
      case Action.rateReceived:
        return Status.success;
      
      // Actions that should set status to canceled
      case Action.canceled:
      case Action.adminCanceled:
      case Action.cooperativeCancelAccepted:
        return Status.canceled;
      
      // For actions that include Order payload, use the payload status
      case Action.newOrder:
      case Action.takeSell:
      case Action.takeBuy:
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
        Action.takeBuy: [
          Action.takeBuy,
          Action.cancel,
        ],
        Action.waitingBuyerInvoice: [
          Action.cancel,
        ],
        Action.payInvoice: [
          Action.payInvoice,
          Action.cancel,
        ],
        Action.newOrder: [
          Action.cancel,
        ],
      },
      Status.active: {
        Action.buyerTookOrder: [
          Action.buyerTookOrder,
          Action.cancel,
          Action.dispute,
        ],
        Action.fiatSentOk: [
          Action.cancel,
          Action.dispute,
          Action.release,
        ],
        Action.rate: [
          Action.rate,
        ],
        Action.purchaseCompleted: [],
        Action.holdInvoicePaymentSettled: [],
        Action.cooperativeCancelInitiatedByPeer: [
          Action.cancel,
        ],
      },
      Status.waitingPayment: {
        Action.payInvoice: [
          Action.payInvoice,
          Action.cancel,
        ],
      },
    },
    Role.buyer: {
      Status.pending: {
        Action.takeSell: [
          Action.takeSell,
          Action.cancel,
        ],
        Action.newOrder: [
          Action.cancel,
        ],
      },
      Status.waitingBuyerInvoice: {
        Action.addInvoice: [
          Action.addInvoice,
          Action.cancel,
        ],
        Action.waitingSellerToPay: [
          Action.cancel,
        ],
      },
      Status.active: {
        Action.holdInvoicePaymentAccepted: [
          Action.holdInvoicePaymentAccepted,
          Action.fiatSent,
          Action.cancel,
          Action.dispute,
        ],
        Action.fiatSentOk: [
          Action.cancel,
          Action.dispute,
        ],
        Action.rate: [
          Action.rate,
        ],
        Action.cooperativeCancelInitiatedByPeer: [
          Action.cancel,
        ],
        Action.rateReceived: [],
        Action.purchaseCompleted: [],
        Action.paymentFailed: [],
      },
    },
  };
}
