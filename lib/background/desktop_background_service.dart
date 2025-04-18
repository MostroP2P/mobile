import 'dart:async';
import 'dart:isolate';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/nostr_filter.dart';
import 'package:mostro_mobile/data/repositories.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/notifications/notification_service.dart';
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/shared/providers/mostro_database_provider.dart';
import 'abstract_background_service.dart';

class DesktopBackgroundService implements BackgroundService {
  // Similar implementation with subscription tracking
  final _subscriptions = <String, Map<String, dynamic>>{};
  bool _isRunning = false;
  late SendPort _sendPort;

  @override
  Future<void> initialize(Settings settings) async {
    final receivePort = ReceivePort();
    await Isolate.spawn(_isolateEntry, receivePort.sendPort);
    _sendPort = await receivePort.first as SendPort;
  }

  static void _isolateEntry(SendPort mainSendPort) async {
    final isolateReceivePort = ReceivePort();
    mainSendPort.send(isolateReceivePort.sendPort);

    final nostrService = NostrService();
    final db = await openMostroDatabase();
    final backgroundStorage = EventStorage(db: db);
    final logger = Logger();
    bool isAppForeground = false;

    isolateReceivePort.listen((message) async {
      if (message is! Map || message['command'] == null) return;

      final command = message['command'];

      switch (command) {
        case 'app-foreground-status':
          isAppForeground = message['isForeground'] ?? false;
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
  }

  @override
  Future<bool> subscribe(Map<String, dynamic> filter) async {
    _sendPort.send(
      {
        'command': 'create-subscription',
        'filter': filter,
      },
    );
    return true;
  }

  @override
  void setForegroundStatus(bool isForeground) {
    _sendPort.send(
      {
        'command': 'app-foreground-status',
        'isForeground': isForeground,
      },
    );
  }

  @override
  Future<int> getActiveSubscriptionCount() async {
    return _subscriptions.length;
  }

  @override
  Future<bool> unsubscribe(String subscriptionId) async {
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
    for (final id in _subscriptions.keys.toList()) {
      await unsubscribe(id);
    }
  }

  @override
  void updateSettings(Settings settings) {
    _sendPort.send(
      {
        'command': 'settings-change',
        'settings': settings.toJson(),
      },
    );
  }
}
