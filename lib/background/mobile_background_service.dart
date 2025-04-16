import 'dart:async';
import 'dart:convert';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:mostro_mobile/background/background.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'abstract_background_service.dart';

class MobileBackgroundService implements BackgroundService {
  final _eventsController = StreamController<Map<String, dynamic>>.broadcast();
  final service = FlutterBackgroundService();
  final _subscriptions = <String, Map<String, dynamic>>{};
  bool _isRunning = false;

  @override
  Future<void> initialize(Settings settings) async {
    await service.configure(
      // Keep existing configurations
      iosConfiguration: IosConfiguration(
        autoStart: false, // Start manually only when needed
        onForeground: serviceMain,
        onBackground: onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
        autoStart: false, // Start manually only when needed
        onStart: serviceMain,
        isForegroundMode: false,
        autoStartOnBoot: false, // Let our subscription logic control this
      ),
    );

    service.on('nostr-event').listen((data) {
      _eventsController.add(data!);
    });
    
    // Initialize with settings but don't start
    service.invoke(
      'settings-change',
      settings.toJson(),
    );
  }

  @override
  Future<bool> subscribe(Map<String, dynamic> filter) async {
    final subscriptionId = _generateSubscriptionId(filter);
    _subscriptions[subscriptionId] = filter;
    
    // Start service if this is the first subscription
    if (_subscriptions.length == 1 && !_isRunning) {
      await _startService();
    }
    
    // Add subscription to the service
    service.invoke(
      'create-subscription',
      {'filter': filter, 'id': subscriptionId},
    );
    
    return true;
  }
  
  @override
  Future<bool> unsubscribe(String subscriptionId) async {
    if (!_subscriptions.containsKey(subscriptionId)) {
      return false;
    }
    
    _subscriptions.remove(subscriptionId);
    service.invoke('cancel-subscription', {'id': subscriptionId});
    
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
  void setForegroundStatus(bool isForeground) {
    service.invoke('app-foreground-status', {
      'isForeground': isForeground,
    });
    
    // When app goes to background but has subscriptions,
    // ensure service keeps running
    if (!isForeground && _subscriptions.isNotEmpty && !_isRunning) {
      _startService();
    }
  }
  
  // Helper methods
  Future<void> _startService() async {
    await service.startService();
    _isRunning = true;
    
    // Re-register all active subscriptions
    for (final entry in _subscriptions.entries) {
      service.invoke(
        'create-subscription',
        {'filter': entry.value, 'id': entry.key},
      );
    }
  }
  
  Future<void> _stopService() async {
    // Use invoke pattern to request the service to stop itself
    service.invoke('stopService');
    _isRunning = false;
  }
  
  String _generateSubscriptionId(Map<String, dynamic> filter) {
    // Generate a unique ID based on filter contents and timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final hashInput = jsonEncode(filter) + timestamp.toString();
    return 'sub_${hashInput.hashCode.abs()}';
  }
}