import 'dart:async';
import 'dart:isolate';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/repositories.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/notifications/notification_service.dart';
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/shared/providers/mostro_database_provider.dart';
import 'abstract_background_service.dart';

class DesktopBackgroundService implements BackgroundService {
  // Similar implementation with subscription tracking
  final _subscriptions = <String, Map<String, dynamic>>{};
  Isolate? _serviceIsolate;
  bool _isRunning = false;
  late SendPort _sendPort;

  @override
  Future<void> initialize(Settings settings) async {
    final receivePort = ReceivePort();
    await Isolate.spawn(_isolateEntry, receivePort.sendPort);
    _sendPort = await receivePort.first as SendPort;

    _sendPort.send({
      'command': 'settings-change',
      'settings': settings.toJson(),
    });
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
        case 'settings-change':
          await nostrService.updateSettings(
            Settings.fromJson(message['settings']),
          );
        case 'subscribe':
          final pList = message['filter']['#p'];
          List<String>? p = pList != null ? [pList[0]] : null;

          final filter = NostrFilter(
            kinds: message['filter']['kinds'],
            p: p,
          );

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
        case 'app-foreground-status':
          isAppForeground = message['isForeground'];
        default:
          logger.i('Unknown command: $command');
      }
    });
  }

  @override
  Future<bool> subscribe(Map<String, dynamic> filter) async {
    _sendPort.send({
      'command': 'subscribe',
      'filter': filter,
    });
    return true;
  }

  @override
  void setForegroundStatus(bool isForeground) {
    _sendPort.send({
      'command': 'app-foreground-status',
      'isForeground': isForeground,
    });
  }

  @override
  Future<int> getActiveSubscriptionCount() {
    // TODO: implement getActiveSubscriptionCount
    throw UnimplementedError();
  }

  @override
  Future<bool> unsubscribe(String subscriptionId) {
    // TODO: implement unsubscribe
    throw UnimplementedError();
  }

  @override
  Future<void> unsubscribeAll() {
    // TODO: implement unsubscribeAll
    throw UnimplementedError();
  }
}
