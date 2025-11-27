import 'dart:async';

import 'package:dart_nostr/nostr/model/request/filter.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/background/background.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'abstract_background_service.dart';

class MobileBackgroundService implements BackgroundService {
  Settings _settings;

  MobileBackgroundService(this._settings);

  final service = FlutterBackgroundService();

  final _subscriptions = <String, Map<String, dynamic>>{};
  bool _isRunning = false;

  bool _serviceReady = false;
  final List<Function> _pendingOperations = [];

  @override
  Future<void> init() async {
    await service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: serviceMain,
        onBackground: onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
          autoStart: false,
          onStart: serviceMain,
          isForegroundMode: false,
          autoStartOnBoot: false,
          initialNotificationTitle: "Mostro",
          initialNotificationContent: "Connected to Mostro service",
          foregroundServiceTypes: [
            AndroidForegroundType.dataSync,
          ]),
    );

    service.on('on-start').listen((data) {
      _isRunning = true;
      service.invoke('start', {
        'settings': _settings.toJson(),
      });
      logger.d(
        'Service started with settings: ${_settings.toJson()}',
      );
    });

    service.on('on-stop').listen((event) {
      _isRunning = false;
      logger.i('Service stopped');
    });

    service.on('service-ready').listen((data) {
      logger.i("Service confirmed it's ready");
      _serviceReady = true;
      _processPendingOperations();
    });
  }

  @override
  void subscribe(List<NostrFilter> filters) {
    final subId = DateTime.now().millisecondsSinceEpoch.toString();
    _subscriptions[subId] = {'filters': filters};

    _executeWhenReady(() {
      logger.i("Sending subscription to service");
      service.invoke('create-subscription', {
        'id': subId,
        'filters': filters.map((f) => f.toMap()).toList(),
      });
    });
  }

  @override
  Future<bool> unsubscribe(String subscriptionId) async {
    if (!_subscriptions.containsKey(subscriptionId)) {
      return false;
    }

    _subscriptions.remove(subscriptionId);
    service.invoke('cancel-subscription', {
      'id': subscriptionId,
    });

    if (_subscriptions.isEmpty && _isRunning) {
      await _stopService();
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
  Future<int> getActiveSubscriptionCount() async {
    return _subscriptions.length;
  }

  @override
  Future<void> setForegroundStatus(bool isForeground) async {
    // Always inform the service about status change
    service.invoke('app-foreground-status', {
      'is-foreground': isForeground,
    });

    // Check current running state first
    final isCurrentlyRunning = await service.isRunning();

    if (isForeground) {
      // Only stop if actually running
      if (isCurrentlyRunning) {
        await _stopService();
      }
    } else {
      // Only start if not already running
      if (!isCurrentlyRunning) {
        try {
          await _startService();
        } catch (e) {
          logger.e('Error starting service: $e');
          // Retry with a delay if needed
          await Future.delayed(Duration(seconds: 1));
          await _startService();
        }
      }
    }
  }

  Future<void> _startService() async {
    logger.i("Starting service");
    await service.startService();
    _serviceReady = false; // Reset ready state when starting

    // Wait for the service to be running
    const maxWait = Duration(seconds: 5);
    final deadline = DateTime.now().add(maxWait);

    while (!(await service.isRunning())) {
      if (DateTime.now().isAfter(deadline)) {
        throw StateError('Background service failed to start within $maxWait');
      }
      await Future.delayed(const Duration(milliseconds: 50));
    }

    logger.i("Service running, sending settings");
    service.invoke('start', {
      'settings': _settings.toJson(),
    });
  }

  Future<void> _stopService() async {
    service.invoke('stop');
    _isRunning = false;
  }

  @override
  void updateSettings(Settings settings) {
    _settings = settings;
    _executeWhenReady(() {
      service.invoke('update-settings', {
        'settings': settings.toJson(),
      });
    });
  }

  @override
  bool get isRunning => _isRunning;

  // Method to execute operations when service is ready
  void _executeWhenReady(Function operation) {
    if (_serviceReady) {
      operation();
    } else {
      _pendingOperations.add(operation);
    }
  }

// Method to process pending operations
  void _processPendingOperations() {
    if (_serviceReady) {
      for (final operation in _pendingOperations) {
        operation();
      }
      _pendingOperations.clear();
    }
  }
}
