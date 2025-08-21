import 'package:mostro_mobile/data/models/enums/action.dart' as actions;
import 'package:mostro_mobile/data/models/notification.dart';
import 'package:mostro_mobile/data/models/enums/notification_type.dart';
import 'package:mostro_mobile/data/repositories/base_storage.dart';
import 'package:sembast/sembast.dart';

/// Repository interface for notifications
abstract class NotificationsRepository {
  Future<List<NotificationModel>> getAllNotifications();
  Future<void> addNotification(NotificationModel notification);
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead();
  Future<void> deleteNotification(String notificationId);
  Future<void> clearAll();
  Stream<List<NotificationModel>> watchNotifications();
  Future<List<NotificationModel>> getUnreadNotifications();
  Future<bool> notificationExists(String notificationId);
}

/// Sembast-based implementation using BaseStorage
class NotificationsStorage extends BaseStorage<NotificationModel> 
    implements NotificationsRepository {
  
  NotificationsStorage({required Database db}) 
      : super(db, stringMapStoreFactory.store('notifications'));

  @override
  NotificationModel fromDbMap(String key, Map<String, dynamic> json) {
    return NotificationModel(
      id: key,
      type: NotificationType.values.firstWhere((type) => 
          type.toString() == json['type']),
      action: actions.Action.fromString(json['action']),
      title: json['title'],
      message: json['message'],
      timestamp: DateTime.parse(json['timestamp']),
      isRead: json['isRead'] ?? false,
      orderId: json['orderId'],
      data: Map<String, dynamic>.from(json['data'] ?? {}),
    );
  }

  @override
  Map<String, dynamic> toDbMap(NotificationModel notification) {
    return {
      'type': notification.type.toString(),
      'action': notification.action.value,
      'title': notification.title,
      'message': notification.message,
      'timestamp': notification.timestamp.toIso8601String(),
      'isRead': notification.isRead,
      'orderId': notification.orderId,
      'data': notification.data,
    };
  }

  // NotificationsRepository interface methods
  @override
  Future<List<NotificationModel>> getAllNotifications() async {
    return await find(
      sort: [SortOrder('timestamp', false)], 
    );
  }

  @override
  Future<void> addNotification(NotificationModel notification) async {
    await putItem(notification.id, notification);
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    final notification = await getItem(notificationId);
    if (notification != null) {
      final updatedNotification = notification.copyWith(isRead: true);
      await putItem(notificationId, updatedNotification);
    }
  }

  @override
  Future<void> markAllAsRead() async {
    await db.transaction((txn) async {
      final notifications = await getAllNotifications();
      for (final notification in notifications) {
        if (!notification.isRead) {
          final updatedNotification = notification.copyWith(isRead: true);
          await store.record(notification.id).put(txn, toDbMap(updatedNotification));
        }
      }
    });
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    await deleteItem(notificationId);
  }

  @override
  Future<void> clearAll() async {
    await deleteAll();
  }

  @override
  Stream<List<NotificationModel>> watchNotifications() {
    return watch(
      sort: [SortOrder('timestamp', false)], // Newest first
    );
  }

  @override
  Future<List<NotificationModel>> getUnreadNotifications() async {
    return await find(
      filter: eq('isRead', false),
      sort: [SortOrder('timestamp', false)],
    );
  }

  @override
  Future<bool> notificationExists(String notificationId) async {
    final record = await getItem(notificationId);
    return record != null;
  }
}

