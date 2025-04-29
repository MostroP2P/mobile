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
      channelDescription: 'Notifications for Mostro trades and messages',
      importance: Importance.max,
      priority: Priority.high,
      visibility: NotificationVisibility.public,
      playSound: true,
      enableVibration: true,
      ticker: 'ticker',
      // Uncomment for heads-up notification, use with care:
      // fullScreenIntent: true,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      // Optionally set interruption level for iOS 15+:
      interruptionLevel: InterruptionLevel.critical,
    ),
  );
  await notificationsPlugin.show(
    event.id.hashCode, // Use unique ID for each event
    'New Mostro Event',
    'You have received a new message from Mostro',
    details,
  );
}
