import 'dart:async';
import 'dart:isolate';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/nostr_filter.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/services/logger_service.dart' as logger_service;
import 'abstract_background_service.dart';

class DesktopBackgroundService implements BackgroundService {
  final _subscriptions = <String, Map<String, dynamic>>{};
  final bool _isRunning = false;
  late SendPort _sendPort;

  DesktopBackgroundService();

  @override
  Future<void> init() async {}

  static void isolateEntry(List<dynamic> args) async {
    final isolateReceivePort = ReceivePort();
    final mainSendPort = args[0] as SendPort;
    final token = args[1] as RootIsolateToken;
    final loggerSendPort = args.length > 2 ? args[2] as SendPort? : null;

    mainSendPort.send(isolateReceivePort.sendPort);

    BackgroundIsolateBinaryMessenger.ensureInitialized(token);

    final logger = Logger(
      printer: logger_service.SimplePrinter(),
      output: logger_service.IsolateLogOutput(loggerSendPort),
      level: Level.debug,
    );

    final nostrService = NostrService();
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
          if (message['filters'] == null) return;

          final filterMap = message['filters'] as List<Map<String, dynamic>>;

          final filters =
              filterMap.map((e) => NostrFilterX.fromJsonSafe(e)).toList();

          final request = NostrRequest(
            filters: filters,
          );

          final subscription = nostrService.subscribeToEvents(request);
          subscription.listen((event) async {
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
  void subscribe(List<NostrFilter> filter) {
    if (!_isRunning) return;

    _sendPort.send(
      {
        'command': 'create-subscription',
        'filter': filter,
      },
    );
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
  bool get isRunning => _isRunning;
}
