import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/notification.dart';
import 'package:mostro_mobile/features/notifications/notifiers/notification_temporary_state.dart';
import 'package:mostro_mobile/features/notifications/notifiers/notifications_notifier.dart';
import 'package:mostro_mobile/features/notifications/notifiers/notifications_state.dart';

final notificationsProvider = 
    StateNotifierProvider<NotificationsNotifier, NotificationsState>(
  (ref) => NotificationsNotifier(ref),
);

final notificationsHistoryProvider = Provider<AsyncValue<List<NotificationModel>>>((ref) {
  final state = ref.watch(notificationsProvider);
  return state.historyNotifications;
});

final temporaryNotificationProvider = Provider<NotificationTemporaryState>((ref) {
  final state = ref.watch(notificationsProvider);
  return state.temporaryNotification;
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsHistoryProvider);
  return notifications.when(
    data: (notificationList) => 
        notificationList.where((notification) => !notification.isRead).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});