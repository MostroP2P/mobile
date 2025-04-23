import 'package:dart_nostr/nostr/model/request/filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/shared/providers/background_service_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';

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
    // Clear active subscriptions
    _activeSubscriptions.clear();
    // Stop background service
    final backgroundService = ref.read(backgroundServiceProvider);
    await backgroundService.setForegroundStatus(true);
    // Reinitialize the mostro service
    ref.read(mostroServiceProvider).init();
    // Reinitialize chat rooms
    final chatRooms = ref.read(chatRoomsNotifierProvider.notifier);
    await chatRooms.loadChats();
  }

  Future<void> _switchToBackground() async {
    _isInBackground = true;
    // Transfer active subscriptions to background service
    final backgroundService = ref.read(backgroundServiceProvider);
    await backgroundService.setForegroundStatus(false);
    backgroundService.subscribe(_activeSubscriptions);
  }

  void addSubscription(NostrFilter filter) {
    _activeSubscriptions.add(filter);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}

// Provider for the lifecycle manager
final lifecycleManagerProvider = Provider((ref) => LifecycleManager(ref));
