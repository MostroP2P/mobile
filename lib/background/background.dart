import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/enums/storage_keys.dart';
import 'package:mostro_mobile/data/models/nostr_filter.dart';
import 'package:mostro_mobile/data/repositories/event_storage.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/notifications/services/background_notification_service.dart' as notification_service;
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/services/logger_service.dart' as logger_service;
import 'package:mostro_mobile/shared/providers/mostro_database_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool isAppForeground = true;
String currentLanguage = 'en';

@pragma('vm:entry-point')
Future<void> serviceMain(ServiceInstance service) async {
  SendPort? loggerSendPort;
  Logger? logger;

  final Map<String, Map<String, dynamic>> activeSubscriptions = {};
  final nostrService = NostrService();
  EventStorage? eventStore;

  bool initialized = false;
  Completer<void>? initInFlight;

  // Register event handlers BEFORE awaiting database open to avoid
  // losing events (e.g. 'start' invoked by FCM handler during db init).
  service.on('app-foreground-status').listen((data) {
    isAppForeground = data?['is-foreground'] ?? isAppForeground;
  });

  service.on('fcm-wake').listen((data) {
    // Service is already running with active subscriptions.
    // Nostr subscriptions will automatically receive new events.
    logger?.d('FCM wake signal received - subscriptions already active');
  });

  service.on('start').listen((data) async {
    if (data == null) return;

    final settingsMap = data['settings'];
    if (settingsMap == null) return;

    // Already fully initialized — just ack.
    if (initialized) {
      service.invoke('service-ready', {});
      return;
    }

    // Another start callback is already initializing — await it and ack.
    // This prevents two overlapping async inits when both FCM handler and
    // MobileBackgroundService fire start before the first one completes.
    if (initInFlight != null) {
      try {
        await initInFlight!.future;
      } catch (_) {
        // First caller's init failed — don't ack readiness.
        return;
      }
      service.invoke('service-ready', {});
      return;
    }

    // Claim the in-flight slot synchronously (before any await) so no
    // other callback can enter the init path.
    initInFlight = Completer<void>();

    try {
      loggerSendPort = IsolateNameServer.lookupPortByName(logger_service.isolatePortName);

      logger = Logger(
        printer: logger_service.SimplePrinter(),
        output: logger_service.IsolateLogOutput(loggerSendPort),
        level: Level.debug,
      );

      final settings = Settings.fromJson(settingsMap);
      currentLanguage = settings.selectedLanguage ?? PlatformDispatcher.instance.locale.languageCode;
      await nostrService.init(settings);

      // Restore persisted subscription filters so the background service can
      // do useful work even when revived from a dead state (e.g. FCM wake
      // after app kill — no LifecycleManager to transfer subscriptions).
      try {
        final prefs = SharedPreferencesAsync();
        final filtersJson = await prefs.getString(
          SharedPreferencesKeys.backgroundFilters.value,
        );
        if (filtersJson != null) {
          final filterList = jsonDecode(filtersJson) as List<dynamic>;
          if (filterList.isNotEmpty) {
            final request = NostrRequestX.fromJson(filterList);
            final subscription = nostrService.subscribeToEvents(request);

            activeSubscriptions[request.subscriptionId!] = {
              'filters': filterList,
              'subscription': subscription,
            };

            subscription.listen((event) async {
              try {
                final store = eventStore;
                if (store != null && await store.hasItem(event.id!)) return;
                await notification_service.retryNotification(event);
              } catch (e) {
                logger?.e('Error processing restored subscription event', error: e);
              }
            });

            logger?.i('Restored ${filterList.length} persisted background filters');
          }
        }
      } catch (e) {
        logger?.e('Failed to restore background filters: $e');
      }

      initialized = true;
      initInFlight!.complete();
      service.invoke('service-ready', {});
    } catch (e) {
      logger?.e('Background service initialization failed', error: e);
      initInFlight!.completeError(e);
    }
  });

  // Signal that Dart handlers are registered and ready to receive events.
  // Sent before database open so callers (e.g. FCM handler) can safely
  // invoke('start') without it being dropped.
  service.invoke('handlers-registered', {});

  final db = await openMostroDatabase('events.db');
  eventStore = EventStorage(db: db);

  service.on('update-settings').listen((data) async {
    if (data == null) return;

    final settingsMap = data['settings'];
    if (settingsMap == null) return;

    final settings = Settings.fromJson(settingsMap);
    currentLanguage = settings.selectedLanguage ?? PlatformDispatcher.instance.locale.languageCode;
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
        final store = eventStore;
        if (store != null && await store.hasItem(event.id!)) {
          return;
        }
        await notification_service.retryNotification(event);
      } catch (e) {
        final currentLogger = logger;
        if (currentLogger != null) {
          currentLogger.e('Error processing event', error: e);
        } else {
          // ignore: avoid_print
          print('ERROR (logger not ready): Error processing event: $e');
        }
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
