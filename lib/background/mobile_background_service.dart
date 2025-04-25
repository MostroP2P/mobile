import 'dart:async';

import 'package:dart_nostr/nostr/model/request/filter.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:mostro_mobile/background/background.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'abstract_background_service.dart';

class MobileBackgroundService implements BackgroundService {
  Settings _settings;

  MobileBackgroundService(this._settings);

  final service = FlutterBackgroundService();

  final _subscriptions = <String, Map<String, dynamic>>{};
  bool _isRunning = false;

  @override
  Future<void> init() async {
    await service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: serviceMain,
        onBackground: onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
          autoStart: true,
          onStart: serviceMain,
          isForegroundMode: true,
          autoStartOnBoot: true,
          initialNotificationTitle: "Mostro P2P",
          initialNotificationContent: "Connected to Mostro service",
          foregroundServiceTypes: [
            AndroidForegroundType.dataSync,
          ]),
    );

    service.on('on-start').listen((data) {
      _isRunning = true;
    });

    service.on('on-stop').listen((event) {
      _isRunning = false;
    });

    service.invoke('start', {
      'settings': _settings.toJson(),
    });
  }

  @override
  void subscribe(List<NostrFilter> filters) {
    final subId = DateTime.now().millisecondsSinceEpoch.toString();
    _subscriptions[subId] = {'filters': filters};

    service.invoke('create-subscription', {
      'id': subId,
      'filters': filters.map((f) => f.toMap()).toList(),
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
        await _startService();
      }
    }
  }

  Future<void> _startService() async {
    await service.startService();

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
  }

  @override
  bool get isRunning => _isRunning;
}
