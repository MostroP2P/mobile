import 'dart:math';

import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';

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
  await flutterLocalNotificationsPlugin.initialize(initSettings);
}

Future<void> showLocalNotification(NostrEvent event) async {
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
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    ),
  );
  await flutterLocalNotificationsPlugin.show(
    event.id.hashCode,
    'New Mostro Event',
    'You have received a new message from Mostro',
    details,
  );
}

Future<void> retryNotification(NostrEvent event, {int maxAttempts = 3}) async {  
  int attempt = 0;  
  bool success = false;  
  
  while (!success && attempt < maxAttempts) {  
    try {  
      await showLocalNotification(event);  
      success = true;  
    } catch (e) {  
      attempt++;  
      if (attempt >= maxAttempts) {  
        Logger().e('Failed to show notification after $maxAttempts attempts: $e');  
        break;  
      }  
      
      // Exponential backoff: 1s, 2s, 4s, etc.  
      final backoffSeconds = pow(2, attempt - 1).toInt();  
      Logger().e('Notification attempt $attempt failed: $e. Retrying in ${backoffSeconds}s');  
      await Future.delayed(Duration(seconds: backoffSeconds));  
    }  
  }  
}  
