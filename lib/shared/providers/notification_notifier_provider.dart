import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/shared/notifiers/notification_notifier.dart';

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>(
        (ref) => NotificationNotifier());
