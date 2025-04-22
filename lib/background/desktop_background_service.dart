import 'dart:async';
import 'dart:isolate';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/nostr_filter.dart';
import 'package:mostro_mobile/data/repositories.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/shared/providers/mostro_database_provider.dart';
import 'abstract_background_service.dart';

class DesktopBackgroundService implements BackgroundService {
  final _eventsController = StreamController<NostrEvent>.broadcast();

  final _subscriptions = <String, Map<String, dynamic>>{};
  bool _isRunning = false;
  late SendPort _sendPort;

  @override
  Future<void> initialize() async {}

  static void _isolateEntry(List<dynamic> args) async {
    final isolateReceivePort = ReceivePort();
    final mainSendPort = args[0] as SendPort;
    final token = args[1] as RootIsolateToken;

    mainSendPort.send(isolateReceivePort.sendPort);

    BackgroundIsolateBinaryMessenger.ensureInitialized(token);

    final nostrService = NostrService();
    final db = await openMostroDatabase('background.db');
    final backgroundStorage = EventStorage(db: db);
    final logger = Logger();
    bool isAppForeground = true;

    isolateReceivePort.listen((message) async {
      if (message is! Map || message['command'] == null) return;

      final command = message['command'];

      switch (command) {
        case 'app-foreground-status':
          isAppForeground = message['is-foreground'] ?? isAppForeground;
          break;
        case 'settings-change':
          if (message['settings'] == null) return;

          await nostrService.updateSettings(
            Settings.fromJson(
              message['settings'],
            ),
          );
          break;
        case 'create-subscription':
          if (message['filter'] == null) return;

          final filter = NostrFilterX.fromJsonSafe(
            message['filter'],
          );

          final subscription = nostrService.subscribeToEvents(filter);
          subscription.listen((event) async {
            await backgroundStorage.putItem(
              event.id!,
              event,
            );
            mainSendPort.send({
              'event': event.toMap(),
            });
            if (!isAppForeground) {
              //await showLocalNotification(event);
            }
          });
          break;
        default:
          logger.i('Unknown command: $command');
          break;
      }
    });

    mainSendPort.send({
      'is-running': true,
    });
  }

  @override
  Future<bool> subscribe(Map<String, dynamic> filter) async {
    if (!_isRunning) return false;

    _sendPort.send(
      {
        'command': 'create-subscription',
        'filter': filter,
      },
    );
    return true;
  }

  @override
  Future<void> setForegroundStatus(bool isForeground) async {
    if (!_isRunning) return;
    _sendPort.send(
      {
        'command': 'app-foreground-status',
        'is-foreground': isForeground,
      },
    );
  }

  @override
  Future<int> getActiveSubscriptionCount() async {
    return _subscriptions.length;
  }

  @override
  Future<bool> unsubscribe(String subscriptionId) async {
    if (!_isRunning) return false;

    if (!_subscriptions.containsKey(subscriptionId)) {
      return false;
    }

    _subscriptions.remove(subscriptionId);
    _sendPort.send(
      {
        'command': 'cancel-subscription',
        'id': subscriptionId,
      },
    );
    // If no more subscriptions, stop the service
    if (_subscriptions.isEmpty && _isRunning) {
      //await _stopService();
    }
    return true;
  }

  @override
  Future<void> unsubscribeAll() async {
    if (!_isRunning) return;
    for (final id in _subscriptions.keys.toList()) {
      await unsubscribe(id);
    }
  }

  @override
  void updateSettings(Settings settings) {
    if (!_isRunning) return;
    _sendPort.send(
      {
        'command': 'settings-change',
        'settings': settings.toJson(),
      },
    );
  }

  @override
  Stream<NostrEvent> get eventsStream => _eventsController.stream;

  @override
  bool get isRunning => _isRunning;
}
