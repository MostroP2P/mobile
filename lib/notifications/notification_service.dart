import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initializeNotifications() async {
  const android = AndroidInitializationSettings(
    '@mipmap/ic_launcher',
  );
  const ios = DarwinInitializationSettings();

  const linux = LinuxInitializationSettings(
    defaultActionName: 'Open',
  );

  const initSettings = InitializationSettings(
    android: android,
    iOS: ios,
    linux: linux,
  );
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(initSettings);
}

Future<void> showNotification(
    int id, String title, String body, String payload) async {
  await flutterLocalNotificationsPlugin.show(
    id,
    title,
    body,
    NotificationDetails(
        android: AndroidNotificationDetails(
      'mostro_channel',
      'Mostro Notifications',
      importance: Importance.max,
    )),
    payload: payload,
  );
}

Future<void> showLocalNotification(NostrEvent event) async {
  final notificationsPlugin = FlutterLocalNotificationsPlugin();
  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'mostro_notifications',
      'Mostro Notifications',
      importance: Importance.max,
    ),
  );
  await notificationsPlugin.show(
    event.createdAt?.millisecondsSinceEpoch ??
        DateTime.now().millisecondsSinceEpoch,
    'New Mostro Event',
    'Action: ${event.kind}',
    details,
  );
}
