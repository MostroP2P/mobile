import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/enums/notification_type.dart';

class NotificationModel {
  final String id;
  final NotificationType type;
  final Action action;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final String? orderId;
  final Map<String, dynamic> data;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.action,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.orderId,
    this.data = const {},
  });

  NotificationModel copyWith({
    String? id,
    NotificationType? type,
    Action? action,
    String? title,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    String? orderId,
    Map<String, dynamic>? data,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      type: type ?? this.type,
      action: action ?? this.action,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      orderId: orderId ?? this.orderId,
      data: data ?? this.data,
    );
  }

  static NotificationType getNotificationTypeFromAction(Action action) {
    switch (action) {
      case Action.newOrder:
      case Action.takeSell:
      case Action.takeBuy:
      case Action.buyerTookOrder:
        return NotificationType.orderUpdate;
      
      case Action.payInvoice:
      case Action.fiatSent:
      case Action.fiatSentOk:
      case Action.release:
      case Action.released:
      case Action.paymentFailed:
      case Action.holdInvoicePaymentAccepted:
      case Action.holdInvoicePaymentSettled:
      case Action.holdInvoicePaymentCanceled:
      case Action.waitingSellerToPay:
      case Action.waitingBuyerInvoice:
      case Action.addInvoice:
      case Action.buyerInvoiceAccepted:
      case Action.purchaseCompleted:
      case Action.invoiceUpdated:
        return NotificationType.payment;
      
      case Action.cancel:
      case Action.canceled:
      case Action.cooperativeCancelInitiatedByYou:
      case Action.cooperativeCancelInitiatedByPeer:
      case Action.cooperativeCancelAccepted:
      case Action.adminCancel:
      case Action.adminCanceled:
        return NotificationType.cancellation;
      
      case Action.dispute:
      case Action.disputeInitiatedByYou:
      case Action.disputeInitiatedByPeer:
      case Action.adminSettle:
      case Action.adminSettled:
      case Action.adminAddSolver:
      case Action.adminTakeDispute:
      case Action.adminTookDispute:
        return NotificationType.dispute;
      
      case Action.rate:
      case Action.rateUser:
      case Action.rateReceived:
        return NotificationType.tradeUpdate;
      
      case Action.sendDm:
        return NotificationType.message;
      case Action.cantDo:
      case Action.tradePubkey:
      case Action.timeoutReversal:
        return NotificationType.system;
    }
  }
}