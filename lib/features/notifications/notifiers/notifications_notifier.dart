import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/repositories/notifications_history_repository.dart';
import 'package:mostro_mobile/data/models/notification.dart';
import 'package:mostro_mobile/shared/providers/notifications_history_repository_provider.dart';

class NotificationsNotifier extends StateNotifier<AsyncValue<List<NotificationModel>>> {
  final Ref ref;
  late final NotificationsRepository _repository;
  
  NotificationsNotifier(this.ref) : super(const AsyncValue.loading()) {
    _repository = ref.read(notificationsRepositoryProvider);
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      state = const AsyncValue.loading();
      final notifications = await _repository.getAllNotifications();
      state = AsyncValue.data(notifications);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }


  Future<void> markAsRead(String notificationId) async {
    await _repository.markAsRead(notificationId);
    state = state.whenData((notifications) => 
      notifications.map((notification) => 
        notification.id == notificationId 
            ? notification.copyWith(isRead: true)
            : notification
      ).toList()
    );
  }

  Future<void> markAllAsRead() async {
    await _repository.markAllAsRead();
    state = state.whenData((notifications) => 
      notifications.map((notification) => 
        notification.copyWith(isRead: true)
      ).toList()
    );
  }

  Future<void> clearAll() async {
    await _repository.clearAll();
    state = const AsyncValue.data([]);
  }

  Future<void> refresh() async {
    await _loadNotifications();
  }

  Future<void> addNotification(NotificationModel notification) async {
    await _repository.addNotification(notification);
    state = state.whenData((notifications) => [
      notification,
      ...notifications,
    ]);
  }

}