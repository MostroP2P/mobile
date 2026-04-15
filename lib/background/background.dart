import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';
import 'package:dart_nostr/dart_nostr.dart';
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

/// Tracks whether the foreground app is currently active.
///
/// Defaults to `false` so notifications fire by default when the background
/// service starts in a state where the foreground app is not up (e.g. after
/// being revived from a kill). The flag is updated via the
/// `app-foreground-status` message sent by the foreground app through
/// `MobileBackgroundService.setForegroundStatus()`.
bool isAppForeground = false;
String currentLanguage = 'en';

/// Callback set by `serviceMain` so that `background_notification_service`
/// can request a new P2P chat subscription when a session transitions to
/// Active while the app is in background.
///
/// Without this, the background service would only have the `orders`
/// subscription (keyed by `tradeKey`). When the counterpart takes the
/// order or the hold invoice is accepted, the peer's tradeKey becomes
/// known, the session can compute the shared key, and we must start
/// listening for P2P chat events on that shared key immediately —
/// otherwise DMs that arrive while the app stays in background would
/// never trigger a notification until the user reopens the app.
///
/// The callback is set inside `serviceMain` (background isolate) so it
/// has access to the local `activeSubscriptions` map, `nostrService`,
/// `eventStore`, and the `logger`. It is `null` in the foreground
/// isolate and any call there is a no-op.
void Function(String sharedKeyPublic)? addChatSubscriptionFromBackground;

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
                // Suppress background notifications while the foreground app
                // is active — the foreground handles events directly and
                // showing a local notification would be redundant (and, for
                // chat echoes, would notify the user of their own messages).
                if (isAppForeground) return;
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

      // Expose a hook that `background_notification_service` can call after
      // it has persisted a peer update to add a live chat subscription
      // without waiting for the foreground app to come back.
      addChatSubscriptionFromBackground = (String sharedKeyPublic) async {
        try {
          // Avoid creating duplicate subscriptions for the same shared key.
          final alreadySubscribed = activeSubscriptions.values.any((entry) {
            final filters = entry['filters'];
            if (filters is! List) return false;
            return filters.any((f) {
              if (f is! Map) return false;
              final p = f['#p'];
              return p is List && p.contains(sharedKeyPublic);
            });
          });
          if (alreadySubscribed) {
            logger?.d('Chat sub for $sharedKeyPublic already active');
            return;
          }

          final filter = NostrFilter(
            kinds: [1059],
            p: [sharedKeyPublic],
          );
          final request = NostrRequest(filters: [filter]);
          final subscription = nostrService.subscribeToEvents(request);

          activeSubscriptions[request.subscriptionId!] = {
            'filters': [filter.toMap()],
            'subscription': subscription,
          };

          subscription.listen((event) async {
            try {
              if (isAppForeground) return;
              final store = eventStore;
              if (store != null && await store.hasItem(event.id!)) return;
              await notification_service.retryNotification(event);
            } catch (e) {
              logger?.e('Error processing chat subscription event', error: e);
            }
          });

          // Persist the new filter so that if the background service is
          // restarted (OS kill, settings update, etc.) the restore path
          // recreates this chat subscription too, not only the original
          // orders filter.
          try {
            final prefs = SharedPreferencesAsync();
            final existingJson = await prefs.getString(
              SharedPreferencesKeys.backgroundFilters.value,
            );
            final currentFilters = existingJson != null
                ? (jsonDecode(existingJson) as List<dynamic>)
                : <dynamic>[];
            currentFilters.add(filter.toMap());
            await prefs.setString(
              SharedPreferencesKeys.backgroundFilters.value,
              jsonEncode(currentFilters),
            );
          } catch (e) {
            logger?.e('Failed to persist updated chat filter: $e');
          }

          logger?.i('Added background chat subscription for $sharedKeyPublic');
        } catch (e, stackTrace) {
          logger?.e(
            'Failed to add background chat subscription',
            error: e,
            stackTrace: stackTrace,
          );
        }
      };

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
        // Suppress background notifications while the foreground app is
        // active — the foreground handles events directly and showing a
        // local notification would be redundant (and, for chat echoes,
        // would notify the user of their own messages).
        if (isAppForeground) return;
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
