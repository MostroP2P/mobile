import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/repositories/notifications_history_repository.dart';
import 'package:mostro_mobile/data/models/notification.dart';
import 'package:mostro_mobile/shared/providers/notifications_history_repository_provider.dart';
import 'package:mostro_mobile/data/enums.dart';

class NotificationTemporaryState {
  final Action? action;
  final Map<String, dynamic> values;
  final bool show;

  NotificationTemporaryState({
    this.action,
    this.values = const {},
    this.show = false,
  });
}

class NotificationsState {
  final AsyncValue<List<NotificationModel>> historyNotifications;
  final NotificationTemporaryState temporaryNotification;

  NotificationsState({
    required this.historyNotifications,
    required this.temporaryNotification,
  });

  NotificationsState copyWith({
    AsyncValue<List<NotificationModel>>? historyNotifications,
    NotificationTemporaryState? temporaryNotification,
  }) {
    return NotificationsState(
      historyNotifications: historyNotifications ?? this.historyNotifications,
      temporaryNotification: temporaryNotification ?? this.temporaryNotification,
    );
  }
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  final Ref ref;
  late final NotificationsRepository _repository;
  
  NotificationsNotifier(this.ref) : super(NotificationsState(
    historyNotifications: const AsyncValue.loading(),
    temporaryNotification: NotificationTemporaryState(),
  )) {
    _repository = ref.read(notificationsRepositoryProvider);
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      state = state.copyWith(historyNotifications: const AsyncValue.loading());
      final notifications = await _repository.getAllNotifications();
      state = state.copyWith(historyNotifications: AsyncValue.data(notifications));
    } catch (error, stackTrace) {
      state = state.copyWith(historyNotifications: AsyncValue.error(error, stackTrace));
    }
  }


  Future<void> markAsRead(String notificationId) async {
    await _repository.markAsRead(notificationId);
    final updatedNotifications = state.historyNotifications.whenData((notifications) => 
      notifications.map((notification) => 
        notification.id == notificationId 
            ? notification.copyWith(isRead: true)
            : notification
      ).toList()
    );
    state = state.copyWith(historyNotifications: updatedNotifications);
  }

  Future<void> markAllAsRead() async {
    await _repository.markAllAsRead();
    final updatedNotifications = state.historyNotifications.whenData((notifications) => 
      notifications.map((notification) => 
        notification.copyWith(isRead: true)
      ).toList()
    );
    state = state.copyWith(historyNotifications: updatedNotifications);
  }

  Future<void> clearAll() async {
    await _repository.clearAll();
    state = state.copyWith(historyNotifications: const AsyncValue.data([]));
  }

  Future<void> refresh() async {
    await _loadNotifications();
  }

  Future<void> addNotification(NotificationModel notification) async {
    await _repository.addNotification(notification);
    final updatedNotifications = state.historyNotifications.whenData((notifications) => [
      notification,
      ...notifications,
    ]);
    state = state.copyWith(historyNotifications: updatedNotifications);
  }

  Future<void> deleteNotification(String notificationId) async {
    await _repository.deleteNotification(notificationId);
    final updatedNotifications = state.historyNotifications.whenData((notifications) => 
      notifications.where((notification) => notification.id != notificationId).toList()
    );
    state = state.copyWith(historyNotifications: updatedNotifications);
  }

  void showTemporary(Action action, {Map<String, dynamic> values = const {}}) {
    state = state.copyWith(
      temporaryNotification: NotificationTemporaryState(
        action: action,
        values: values,
        show: true,
      ),
    );
  }

  void clearTemporary() {
    state = state.copyWith(
      temporaryNotification: NotificationTemporaryState(),
    );
  }

  Future<void> addToHistory(Action action, {Map<String, dynamic> values = const {}, String? orderId}) async {
    final notification = NotificationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: NotificationModel.getNotificationTypeFromAction(action),
      action: action,
      title: _getNotificationTitleKey(action),
      message: _getNotificationMessageKey(action),
      timestamp: DateTime.now(),
      orderId: orderId,
      data: values,
    );
    await addNotification(notification);
  }

  Future<void> notify(Action action, {Map<String, dynamic> values = const {}, String? orderId}) async {
    showTemporary(action, values: values);
    await addToHistory(action, values: values, orderId: orderId);
  }

  String _getNotificationTitleKey(Action action) {
    switch (action) {
      case Action.newOrder:
        return 'notification_new_order_title';
      case Action.takeBuy:
      case Action.takeSell:
        return 'notification_order_taken_title';
      case Action.payInvoice:
        return 'notification_payment_required_title';
      case Action.fiatSent:
        return 'notification_fiat_sent_title';
      case Action.fiatSentOk:
        return 'notification_fiat_sent_ok_title';
      case Action.release:
        return 'notification_release_title';
      case Action.released:
        return 'notification_bitcoin_released_title';
      case Action.buyerInvoiceAccepted:
        return 'notification_buyer_invoice_accepted_title';
      case Action.purchaseCompleted:
        return 'notification_purchase_completed_title';
      case Action.holdInvoicePaymentAccepted:
        return 'notification_hold_invoice_payment_accepted_title';
      case Action.holdInvoicePaymentSettled:
        return 'notification_hold_invoice_payment_settled_title';
      case Action.holdInvoicePaymentCanceled:
        return 'notification_hold_invoice_payment_canceled_title';
      case Action.waitingSellerToPay:
        return 'notification_waiting_seller_to_pay_title';
      case Action.waitingBuyerInvoice:
        return 'notification_waiting_buyer_invoice_title';
      case Action.addInvoice:
        return 'notification_add_invoice_title';
      case Action.buyerTookOrder:
        return 'notification_buyer_took_order_title';
      case Action.rate:
      case Action.rateUser:
        return 'notification_rate_title';
      case Action.rateReceived:
        return 'notification_rate_received_title';
      case Action.dispute:
        return 'notification_dispute_started_title';
      case Action.disputeInitiatedByYou:
        return 'notification_dispute_initiated_by_you_title';
      case Action.disputeInitiatedByPeer:
        return 'notification_dispute_initiated_by_peer_title';
      case Action.paymentFailed:
        return 'notification_payment_failed_title';
      case Action.invoiceUpdated:
        return 'notification_invoice_updated_title';
      case Action.cantDo:
        return 'notification_cant_do_title';
      case Action.canceled:
        return 'notification_order_canceled_title';
      case Action.cooperativeCancelInitiatedByYou:
        return 'notification_cooperative_cancel_initiated_by_you_title';
      case Action.cooperativeCancelInitiatedByPeer:
        return 'notification_cooperative_cancel_initiated_by_peer_title';
      case Action.cooperativeCancelAccepted:
        return 'notification_cooperative_cancel_accepted_title';
      case Action.sendDm:
        return 'notification_new_message_title';
      default:
        return 'notification_order_update_title';
    }
  }

  String _getNotificationMessageKey(Action action) {
    switch (action) {
      case Action.newOrder:
        return 'notification_new_order_message';
      case Action.takeBuy:
        return 'notification_sell_order_taken_message';
      case Action.takeSell:
        return 'notification_buy_order_taken_message';
      case Action.payInvoice:
        return 'notification_payment_required_message';
      case Action.fiatSent:
        return 'notification_fiat_sent_message';
      case Action.fiatSentOk:
        return 'notification_fiat_sent_ok_message';
      case Action.release:
        return 'notification_release_message';
      case Action.released:
        return 'notification_bitcoin_released_message';
      case Action.buyerInvoiceAccepted:
        return 'notification_buyer_invoice_accepted_message';
      case Action.purchaseCompleted:
        return 'notification_purchase_completed_message';
      case Action.holdInvoicePaymentAccepted:
        return 'notification_hold_invoice_payment_accepted_message';
      case Action.holdInvoicePaymentSettled:
        return 'notification_hold_invoice_payment_settled_message';
      case Action.holdInvoicePaymentCanceled:
        return 'notification_hold_invoice_payment_canceled_message';
      case Action.waitingSellerToPay:
        return 'notification_waiting_seller_to_pay_message';
      case Action.waitingBuyerInvoice:
        return 'notification_waiting_buyer_invoice_message';
      case Action.addInvoice:
        return 'notification_add_invoice_message';
      case Action.buyerTookOrder:
        return 'notification_buyer_took_order_message';
      case Action.rate:
      case Action.rateUser:
        return 'notification_rate_message';
      case Action.rateReceived:
        return 'notification_rate_received_message';
      case Action.dispute:
        return 'notification_dispute_started_message';
      case Action.disputeInitiatedByYou:
        return 'notification_dispute_initiated_by_you_message';
      case Action.disputeInitiatedByPeer:
        return 'notification_dispute_initiated_by_peer_message';
      case Action.paymentFailed:
        return 'notification_payment_failed_message';
      case Action.invoiceUpdated:
        return 'notification_invoice_updated_message';
      case Action.cantDo:
        return 'notification_cant_do_message';
      case Action.canceled:
        return 'notification_order_canceled_message';
      case Action.cooperativeCancelInitiatedByYou:
        return 'notification_cooperative_cancel_initiated_by_you_message';
      case Action.cooperativeCancelInitiatedByPeer:
        return 'notification_cooperative_cancel_initiated_by_peer_message';
      case Action.cooperativeCancelAccepted:
        return 'notification_cooperative_cancel_accepted_message';
      case Action.sendDm:
        return 'notification_new_message_message';
      default:
        return 'notification_order_update_message';
    }
  }

}