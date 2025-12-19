import 'dart:io';

import 'package:dart_nostr/nostr/model/request/filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/services/logger_service.dart';
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
      logger.i("Lifecycle: switching to foreground");

      // Stop background service
      final backgroundService = ref.read(backgroundServiceProvider);
      await backgroundService.setForegroundStatus(true);
      logger.i("BackgroundService: foreground status set to true");

      // Add a small delay to ensure the background service has fully transitioned
      await Future.delayed(const Duration(milliseconds: 500));

      final subscriptionManager = ref.read(subscriptionManagerProvider);
      subscriptionManager.subscribeAll();

      // Reinitialize the mostro service
      logger.i("MostroService: reinitializing");
      ref.read(mostroServiceProvider).init();

      // Refresh order repository by re-reading it
      logger.i("Repository: refreshing orders");
      final orderRepo = ref.read(orderRepositoryProvider);
      orderRepo.reloadData();

      // Reinitialize chat rooms
      logger.i("Chat: reloading rooms");
      final chatRooms = ref.read(chatRoomsNotifierProvider.notifier);
      chatRooms.reloadAllChats();

      // Force UI update for trades
      logger.i("UI: invalidating providers to refresh");
      ref.invalidate(filteredTradesWithOrderStateProvider);

      logger.i("Lifecycle: foreground transition complete");
    } catch (e) {
      logger.e("Error during foreground transition: $e");
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
          logger.d('Subscription: found ${filters.length} active filters for $type');
          activeFilters.addAll(filters);
        }
      }

      if (activeFilters.isNotEmpty) {
        _isInBackground = true;
        logger.i("Lifecycle: switching to background");
        subscriptionManager.unsubscribeAll();
        // Transfer active subscriptions to background service
        final backgroundService = ref.read(backgroundServiceProvider);
        await backgroundService.setForegroundStatus(false);
        logger.i("BackgroundService: transferring ${activeFilters.length} active filters");
        backgroundService.subscribe(activeFilters);
      } else {
        logger.w("BackgroundService: no active subscriptions to transfer");
      }

      logger.i("Lifecycle: background transition complete");
    } catch (e) {
      logger.e("Lifecycle: background transition failed - $e");
    }
  }

  @Deprecated('Use SubscriptionManager instead.')
  void addSubscription(NostrFilter filter) {
    logger.w('Lifecycle: addSubscription deprecated - use SubscriptionManager instead');
    // No-op - subscriptions are now tracked by SubscriptionManager
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}

// Provider for the lifecycle manager
final lifecycleManagerProvider = Provider((ref) => LifecycleManager(ref));
