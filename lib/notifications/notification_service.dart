import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initializeNotifications() async {
  const android = AndroidInitializationSettings(
    '@drawable/ic_bg_service_small',
  );
  const ios = DarwinInitializationSettings();

  const linux = LinuxInitializationSettings(
    defaultActionName: 'Open',
  );

  const initSettings = InitializationSettings(
    android: android,
    iOS: ios,
    linux: linux,
    macOS: ios
  );
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(initSettings);
}

Future<void> showLocalNotification(NostrEvent event) async {
  final notificationsPlugin = FlutterLocalNotificationsPlugin();
  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'mostro_channel',
      'Mostro Notifications',
      importance: Importance.max,
    ),
  );
  await notificationsPlugin.show(
    0,
    'New Mostro Event',
    'You have received a new message from Mostro',
    details,
  );
}
