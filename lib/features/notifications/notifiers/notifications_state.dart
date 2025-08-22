import 'package:mostro_mobile/features/notifications/notifiers/notification_temporary_state.dart';

class TemporaryNotificationsState {
  final TemporaryNotification temporaryNotification;

  const TemporaryNotificationsState({
    required this.temporaryNotification,
  });

  TemporaryNotificationsState copyWith({
    TemporaryNotification? temporaryNotification,
  }) {
    return TemporaryNotificationsState(
      temporaryNotification: temporaryNotification ?? this.temporaryNotification,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemporaryNotificationsState &&
          runtimeType == other.runtimeType &&
          temporaryNotification == other.temporaryNotification;

  @override
  int get hashCode => temporaryNotification.hashCode;

  @override
  String toString() {
    return 'TemporaryNotificationsState(temporaryNotification: $temporaryNotification)';
  }
}