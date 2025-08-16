import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/notification.dart';
import 'package:mostro_mobile/features/notifications/notifiers/notification_temporary_state.dart';

class NotificationsState {
  final AsyncValue<List<NotificationModel>> historyNotifications;
  final NotificationTemporaryState temporaryNotification;

  const NotificationsState({
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationsState &&
          runtimeType == other.runtimeType &&
          historyNotifications == other.historyNotifications &&
          temporaryNotification == other.temporaryNotification;

  @override
  int get hashCode => Object.hash(historyNotifications, temporaryNotification);

  @override
  String toString() {
    return 'NotificationsState(historyNotifications: $historyNotifications, temporaryNotification: $temporaryNotification)';
  }
}