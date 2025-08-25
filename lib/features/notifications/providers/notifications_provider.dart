import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/notification.dart';
import 'package:mostro_mobile/features/notifications/notifiers/notification_temporary_state.dart';
import 'package:mostro_mobile/features/notifications/notifiers/notifications_notifier.dart';
import 'package:mostro_mobile/features/notifications/notifiers/notifications_state.dart';
import 'package:mostro_mobile/shared/providers/notifications_history_repository_provider.dart';

// Notification actions (shows toasts + saves to DB)
final notificationActionsProvider = 
    StateNotifierProvider<NotificationsNotifier, TemporaryNotificationsState>(
  (ref) => NotificationsNotifier(ref),
);

// Persistent notifications from database - single source of truth
final notificationsHistoryProvider = StreamProvider<List<NotificationModel>>((ref) {
  final repository = ref.read(notificationsRepositoryProvider);
  return repository.watchNotifications();
});

// Direct database operations (mark read, delete, etc.)
final notificationsDatabaseProvider = Provider((ref) {
  return ref.read(notificationsRepositoryProvider);
});

// Current temporary notification state (for toasts/snackbars)
final currentTemporaryNotificationProvider = Provider<TemporaryNotification>((ref) {
  final state = ref.watch(notificationActionsProvider);
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