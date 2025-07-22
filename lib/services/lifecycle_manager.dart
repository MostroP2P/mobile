import 'dart:io';

import 'package:dart_nostr/nostr/model/request/filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_type.dart';
import 'package:mostro_mobile/features/trades/providers/trades_provider.dart';
import 'package:mostro_mobile/shared/providers/background_service_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager_provider.dart';

class LifecycleManager extends WidgetsBindingObserver {
  final Ref ref;
  bool _isInBackground = false;
  final _logger = Logger();

  LifecycleManager(this.ref) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (Platform.isAndroid || Platform.isIOS) {
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
  }

  Future<void> _switchToForeground() async {
    try {
      _isInBackground = false;
      _logger.i("Switching to foreground");

      // Stop background service
      final backgroundService = ref.read(backgroundServiceProvider);
      await backgroundService.setForegroundStatus(true);
      _logger.i("Background service foreground status set to true");

      // Add a small delay to ensure the background service has fully transitioned
      await Future.delayed(const Duration(milliseconds: 500));

      final subscriptionManager = ref.read(subscriptionManagerProvider);
      subscriptionManager.subscribeAll();

      // Reinitialize the mostro service
      _logger.i("Reinitializing MostroService");
      ref.read(mostroServiceProvider).init();

      // Refresh order repository by re-reading it
      _logger.i("Refreshing order repository");
      final orderRepo = ref.read(orderRepositoryProvider);
      orderRepo.reloadData();

      // Reinitialize chat rooms
      _logger.i("Reloading chat rooms");
      final chatRooms = ref.read(chatRoomsNotifierProvider.notifier);
      chatRooms.reloadAllChats();

      // Force UI update for trades
      _logger.i("Invalidating providers to refresh UI");
      ref.invalidate(filteredTradesWithOrderStateProvider);

      _logger.i("Foreground transition complete");
    } catch (e) {
      _logger.e("Error during foreground transition: $e");
    }
  }

  Future<void> _switchToBackground() async {
    try {
      // Get the subscription manager
      final subscriptionManager = ref.read(subscriptionManagerProvider);
      final activeFilters = <NostrFilter>[];
      
      // Get actual filters for each subscription type
      for (final type in SubscriptionType.values) {
        final filters = subscriptionManager.getActiveFilters(type);
        if (filters.isNotEmpty) {
          _logger.d('Found ${filters.length} active filters for $type');
          activeFilters.addAll(filters);
        }
      }

      if (activeFilters.isNotEmpty) {
        _isInBackground = true;
        _logger.i("Switching to background");
        subscriptionManager.unsubscribeAll();
        // Transfer active subscriptions to background service
        final backgroundService = ref.read(backgroundServiceProvider);
        await backgroundService.setForegroundStatus(false);
        _logger.i(
            "Transferring ${activeFilters.length} active filters to background service");
        backgroundService.subscribe(activeFilters);
      } else {
        _logger.w("No active subscriptions to transfer to background service");
      }

      _logger.i("Background transition complete");
    } catch (e) {
      _logger.e("Error during background transition: $e");
    }
  }

  @Deprecated('Use SubscriptionManager instead.')
  void addSubscription(NostrFilter filter) {
    _logger.w('LifecycleManager.addSubscription is deprecated. Use SubscriptionManager instead.');
    // No-op - subscriptions are now tracked by SubscriptionManager
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}

// Provider for the lifecycle manager
final lifecycleManagerProvider = Provider((ref) => LifecycleManager(ref));
