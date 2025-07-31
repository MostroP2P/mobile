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
    );
    await addNotification(notification);
  }

  Future<void> notifyBoth(Action action, {Map<String, dynamic> values = const {}, String? orderId}) async {
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
      case Action.released:
        return 'notification_bitcoin_released_title';
      case Action.dispute:
        return 'notification_dispute_started_title';
      case Action.canceled:
        return 'notification_order_canceled_title';
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
      case Action.released:
        return 'notification_bitcoin_released_message';
      case Action.dispute:
        return 'notification_dispute_started_message';
      case Action.canceled:
        return 'notification_order_canceled_message';
      case Action.sendDm:
        return 'notification_new_message_message';
      default:
        return 'notification_order_update_message';
    }
  }

}