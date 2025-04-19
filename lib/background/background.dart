import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/data/models/nostr_filter.dart';
import 'package:mostro_mobile/data/repositories/event_storage.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/shared/providers/mostro_database_provider.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

bool isAppForeground = false;

@pragma('vm:entry-point')
Future<void> serviceMain(ServiceInstance service) async {
  final dir = await getApplicationSupportDirectory();
  final path = p.join(dir.path, 'mostro', 'databases', 'background.db');

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

  final Map<String, Map<String, dynamic>> activeSubscriptions = {};
  final nostrService = NostrService();

  final db = await openMostroDatabase(path);
  final backgroundStorage = EventStorage(db: db);

  service.on('app-foreground-status').listen((data) {
    isAppForeground = data?['is-foreground'] ?? isAppForeground;
  });

  service.on('settings-change').listen((data) {
    if (data == null) return;

    final settingsMap = data['settings'];
    if (settingsMap == null) return;

    nostrService.init(
      Settings.fromJson(
        settingsMap,
      ),
    );
  });

  service.on('create-subscription').listen((data) {
    if (data == null || data['filter'] == null) return;

    final filter = NostrFilterX.fromJsonSafe(
      data['filter'],
    );

    final subscription = nostrService.subscribeToEvents(filter);
    subscription.listen((event) async {
      await backgroundStorage.putItem(
        event.id!,
        event,
      );
      service.invoke('event', event.toMap());
      if (!isAppForeground) {
        //await showLocalNotification(event);
      }
    });
  });

  service.on('cancel-subscription').listen((event) {
    if (event == null) return;

    final id = event['id'] as String?;
    if (id != null && activeSubscriptions.containsKey(id)) {
      activeSubscriptions.remove(id);
    }
  });

  service.invoke('is-running', {
    'is-running': true,
  });
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  return true;
}
