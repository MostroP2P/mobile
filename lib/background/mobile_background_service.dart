import 'dart:async';

import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:mostro_mobile/background/background.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'abstract_background_service.dart';

class MobileBackgroundService implements BackgroundService {
  Settings _settings;

  MobileBackgroundService(this._settings);

  final service = FlutterBackgroundService();
  final _eventsController = StreamController<NostrEvent>.broadcast();

  final _subscriptions = <String, Map<String, dynamic>>{};
  bool _isRunning = false;

  @override
  Future<void> initialize() async {
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
        autoStartOnBoot: true,
      ),
    );
  }

  @override
  Future<bool> subscribe(Map<String, dynamic> filter) async {
    service.invoke('create-subscription', {
      'filter': filter,
    });

    return true;
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

    // If no more subscriptions, stop the service
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
    if (isForeground) {
      await _stopService();
    } else {
      await _startService();
    }
  }

  Future<void> _startService() async {
    await service.startService();

    while (!(await service.isRunning())) {
      await Future.delayed(const Duration(milliseconds: 50));
    }

    service.invoke('settings-change', {
      'settings': _settings.toJson(),
    });

    // Re-register all active subscriptions
    for (final entry in _subscriptions.entries) {
      service.invoke('create-subscription', {
        'filter': entry.value,
        'id': entry.key,
      });
    }
  }

  Future<void> _stopService() async {
    // Use invoke pattern to request the service to stop itself
    service.invoke('stopService');
    _isRunning = false;
  }

  @override
  void updateSettings(Settings settings) {
    _settings = settings;
  }

  @override
  Stream<NostrEvent> get eventsStream => _eventsController.stream;

  @override
  bool get isRunning => _isRunning;
}
