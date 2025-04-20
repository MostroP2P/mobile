import 'package:dart_nostr/nostr/model/request/filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/shared/providers/background_service_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';

class LifecycleManager extends WidgetsBindingObserver {
  final Ref ref;
  bool _isInBackground = false;
  final List<NostrFilter> _activeSubscriptions = [];

  LifecycleManager(this.ref) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        // App is in foreground
        if (_isInBackground) {
          await _switchToForeground();
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // App is in background
        if (!_isInBackground) {
          await _switchToBackground();
        }
        break;
      default:
        break;
    }
  }

  Future<void> _switchToForeground() async {
    _isInBackground = false;

    // Stop background service
    final backgroundService = ref.read(backgroundServiceProvider);
    backgroundService.setForegroundStatus(true);

    await ref.read(nostrServiceProvider).syncBackgroundEvents();

    // Re-establish direct subscriptions
    final nostrService = ref.read(nostrServiceProvider);
    for (final subscription in _activeSubscriptions) {
      nostrService.subscribeToEvents(subscription);
    }
  }

  Future<void> _switchToBackground() async {
    _isInBackground = true;

    // Transfer active subscriptions to background service
    final backgroundService = ref.read(backgroundServiceProvider);
    backgroundService.setForegroundStatus(false);

    for (final subscription in _activeSubscriptions) {
      await backgroundService.subscribe(subscription.toMap());
    }
  }

  void addSubscription(NostrFilter filter) {
    _activeSubscriptions.add(filter);
    final nostrService = ref.read(nostrServiceProvider);
    nostrService.subscribeToEvents(filter);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}

// Provider for the lifecycle manager
final lifecycleManagerProvider = Provider((ref) => LifecycleManager(ref));
