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
  void subscribe(Map<String, dynamic> filter) {
    _sendPort.send({
      'command': 'subscribe',
      'filter': filter,
    });
  }

  @override
  void setForegroundStatus(bool isForeground) {
    _sendPort.send({
      'command': 'app-foreground-status',
      'isForeground': isForeground,
    });
  }
}
