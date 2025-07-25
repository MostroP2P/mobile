import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/nostr_filter.dart';
import 'package:mostro_mobile/data/repositories/event_storage.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/notifications/notification_service.dart';
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/shared/providers/mostro_database_provider.dart';

bool isAppForeground = true;

@pragma('vm:entry-point')
Future<void> serviceMain(ServiceInstance service) async {

  final Map<String, Map<String, dynamic>> activeSubscriptions = {};
  final nostrService = NostrService();
  final db = await openMostroDatabase('events.db');
  final eventStore = EventStorage(db: db);

  service.on('app-foreground-status').listen((data) {
    isAppForeground = data?['is-foreground'] ?? isAppForeground;
  });

  service.on('start').listen((data) async {
    if (data == null) return;

    final settingsMap = data['settings'];
    if (settingsMap == null) return;

    final settings = Settings.fromJson(settingsMap);
    await nostrService.init(settings);

    service.invoke('service-ready', {});
  });

  service.on('update-settings').listen((data) async {
    if (data == null) return;

    final settingsMap = data['settings'];
    if (settingsMap == null) return;

    final settings = Settings.fromJson(settingsMap);
    await nostrService.updateSettings(settings);

    service.invoke('service-ready', {});
  });

  service.on('create-subscription').listen((data) {
    if (data == null || data['filters'] == null) return;

    final filterMap = data['filters'];

    final filters = filterMap.toList();

    final request = NostrRequestX.fromJson(filters);

    final subscription = nostrService.subscribeToEvents(request);

    activeSubscriptions[request.subscriptionId!] = {
      'filters': filters,
      'subscription': subscription,
    };

    subscription.listen((event) async {
      try {
        if (await eventStore.hasItem(event.id!)) return;
        await retryNotification(event);
      } catch (e) {
        Logger().e('Error processing event', error: e);
      }
    });
  });

  service.on('cancel-subscription').listen((event) {
    if (event == null) return;

    final id = event['id'] as String?;
    if (id != null && activeSubscriptions.containsKey(id)) {
      activeSubscriptions.remove(id);
      nostrService.unsubscribe(id);
    }
  });

  service.on("stop").listen((event) async {
    nostrService.disconnectFromRelays();
    await db.close();
    service.stopSelf();
  });

  service.invoke('on-start', {
    'isRunning': true,
  });
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  return true;
}
