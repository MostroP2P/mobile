import 'dart:async';
import 'dart:ui';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/data/repositories/event_storage.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/notifications/notification_service.dart';
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/shared/providers/mostro_database_provider.dart';

bool isAppForeground = false;

@pragma('vm:entry-point')
Future<void> serviceMain(ServiceInstance service) async {
  // If on Android, set up a permanent notification so the OS won't kill it.
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    const androidDetails = AndroidNotificationDetails(
      'mostro_foreground',
      'Mostro Foreground Service',
      icon: '@mipmap/ic_launcher',
      priority: Priority.high,
      importance: Importance.max,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    await flutterLocalNotificationsPlugin.show(
      Config.notificationId,
      'Mostro is running',
      'Connected to Nostr...',
      notificationDetails,
    );
  }

  final nostrService = NostrService();
  final db = await openMostroDatabase();
  final backgroundStorage = EventStorage(db: db);

  service.on('app-foreground-status').listen((data) {
    isAppForeground = data?['isForeground'] ?? false;
  });

  service.on('settings-change').listen((data) async {
    await nostrService.init(
      Settings.fromJson(data!['settings']),
    );
  });

  // Listen for commands from the main isolate
  service.on('create-subscription').listen((data) {
    final filter = NostrFilter.fromJson(data?['filter']);
    final subscription = nostrService.subscribeToEvents(filter);
    subscription.listen((event) async {
      await backgroundStorage.putItem(
        event.subscriptionId!,
        event,
      );
      if (!isAppForeground) {
        await showLocalNotification(event);
      }
    });
  });
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  return true;
}
