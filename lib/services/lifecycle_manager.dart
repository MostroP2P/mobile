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
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/features/notifications/services/background_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LifecycleManager extends WidgetsBindingObserver {
  final Ref ref;
  bool _isInBackground = false;
  final _logger = Logger();

  LifecycleManager(this.ref) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    _logger.i('App lifecycle state changed to: $state');

    if (Platform.isAndroid || Platform.isIOS) {
      switch (state) {
        case AppLifecycleState.resumed:
          if (_isInBackground) {
            await _switchToForeground();
          }
          break;
        case AppLifecycleState.paused:
        case AppLifecycleState.inactive:
        case AppLifecycleState.detached:
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

      await _checkPendingFCMEvents();

      // Stop background service
      final backgroundService = ref.read(backgroundServiceProvider);
      await backgroundService.setForegroundStatus(true);

      // Add a small delay to ensure the background service has fully transitioned
      await Future.delayed(const Duration(milliseconds: 500));

      final subscriptionManager = ref.read(subscriptionManagerProvider);
      subscriptionManager.subscribeAll();

      // Reinitialize the mostro service
      ref.read(mostroServiceProvider).init();

      // Refresh order repository
      final orderRepo = ref.read(orderRepositoryProvider);
      orderRepo.reloadData();

      // Reinitialize chat rooms
      final chatRooms = ref.read(chatRoomsNotifierProvider.notifier);
      chatRooms.reloadAllChats();

      // Force UI update for trades
      ref.invalidate(filteredTradesWithOrderStateProvider);

      _logger.i("Foreground transition complete");
    } catch (e) {
      _logger.e("Error during foreground transition: $e");
    }
  }

  Future<void> _checkPendingFCMEvents() async {
    try {
      final sharedPrefs = SharedPreferencesAsync();
      final hasPending = await sharedPrefs.getBool('fcm.pending_fetch') ?? false;

      if (hasPending) {
        _logger.i('Pending FCM events detected - processing now');

        await sharedPrefs.setBool('fcm.pending_fetch', false);

        final settings = ref.read(settingsProvider);
        final relays = settings.relays;

        if (relays.isEmpty) {
          _logger.w('No relays configured - cannot fetch events');
          return;
        }

        _logger.i('Fetching new events from ${relays.length} relays');
        await fetchAndProcessNewEvents(relays: relays);
        _logger.i('Successfully processed pending FCM events');
      }
    } catch (e, stackTrace) {
      _logger.e('Error processing pending FCM events: $e');
      _logger.e('Stack trace: $stackTrace');
    }
  }

  Future<void> _switchToBackground() async {
    try {
      _isInBackground = true;
      _logger.i("Switching to background");

      // Get the subscription manager
      final subscriptionManager = ref.read(subscriptionManagerProvider);
      final activeFilters = <NostrFilter>[];

      // Get actual filters for each subscription type
      for (final type in SubscriptionType.values) {
        final filters = subscriptionManager.getActiveFilters(type);
        if (filters.isNotEmpty) {
          activeFilters.addAll(filters);
        }
      }

      if (activeFilters.isNotEmpty) {
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
