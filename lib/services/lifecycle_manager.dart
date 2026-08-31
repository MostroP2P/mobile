import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_nostr/nostr/model/request/filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/storage_keys.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/features/disputes/notifiers/dispute_chat_notifier.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_type.dart';
import 'package:mostro_mobile/shared/providers/background_service_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LifecycleManager extends WidgetsBindingObserver {
  final Ref ref;
  final bool _isMobilePlatform;
  bool _isInBackground = false;
  Timer? _backgroundDebounce;

  /// A background switch is expensive (unsubscribe everything, start the
  /// background service) and the matching resume redoes cold-start work, so
  /// it only runs once the app has stayed away for this long. A quick resume
  /// cancels it.
  static const Duration backgroundDebounce = Duration(seconds: 2);

  @visibleForTesting
  bool get isInBackground => _isInBackground;

  LifecycleManager(this.ref, {bool? isMobilePlatform})
      : _isMobilePlatform =
            isMobilePlatform ?? (Platform.isAndroid || Platform.isIOS) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (!_isMobilePlatform) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _backgroundDebounce?.cancel();
        _backgroundDebounce = null;
        if (_isInBackground) {
          await _switchToForeground();
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // Schedule, don't switch: paused can be a blip (app switcher glance).
        if (!_isInBackground && _backgroundDebounce == null) {
          _backgroundDebounce = Timer(backgroundDebounce, () {
            _backgroundDebounce = null;
            if (!_isInBackground) {
              _switchToBackground();
            }
          });
        }
        break;
      case AppLifecycleState.inactive:
        // Fires for the notification shade, permission/biometric dialogs and
        // the app switcher on Android. Never a reason to tear down
        // subscriptions and start the background service.
        //
        // A pending switch is cancelled here, not only on `resumed`: the
        // return path is paused -> hidden -> inactive -> resumed, and the app
        // can sit in `inactive` past the deadline behind a permission or
        // biometric dialog. Letting the timer fire there would run the whole
        // teardown while the app is already coming back, which is exactly the
        // churn the debounce exists to avoid. Nothing is stranded by this:
        // leaving `inactive` outwards delivers `hidden`, which reschedules.
        _backgroundDebounce?.cancel();
        _backgroundDebounce = null;
        break;
    }
  }

  Future<void> _switchToForeground() async {
    try {
      _isInBackground = false;
      logger.i("Switching to foreground");

      // Clear persisted background filters since foreground takes over
      final prefs = SharedPreferencesAsync();
      await prefs.remove(SharedPreferencesKeys.backgroundFilters.value);

      // Stop background service
      final backgroundService = ref.read(backgroundServiceProvider);
      await backgroundService.setForegroundStatus(true);
      logger.i("Background service foreground status set to true");

      // Add a small delay to ensure the background service has fully transitioned
      await Future.delayed(const Duration(milliseconds: 500));

      final subscriptionManager = ref.read(subscriptionManagerProvider);
      // resume() rather than subscribeAll(): the relay-list subscription is
      // not derived from sessions, so subscribeAll() alone cannot bring it
      // back after _switchToBackground() tore it down.
      subscriptionManager.resume();

      // Reinitialize the mostro service
      logger.i("Reinitializing MostroService");
      ref.read(mostroServiceProvider).init();

      // Refresh order repository by re-reading it
      logger.i("Refreshing order repository");
      final orderRepo = ref.read(orderRepositoryProvider);
      orderRepo.reloadData();

      // Reinitialize chat rooms (await to ensure messages are loaded
      // before UI refresh, preventing empty-chat race condition)
      logger.i("Reloading chat rooms");
      final chatRooms = ref.read(chatRoomsNotifierProvider.notifier);
      await chatRooms.reloadAllChats();

      // Reload dispute chats: the background service persists admin messages
      // to disk while the app sleeps, but an already-initialized notifier
      // never re-reads storage nor re-opens its relay subscription on its own
      logger.i("Reloading dispute chats");
      ref.invalidate(disputeChatNotifierProvider);

      logger.i("Foreground transition complete");
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
          logger.d('Found ${filters.length} active filters for $type');
          activeFilters.addAll(filters);
        }
      }

      final prefs = SharedPreferencesAsync();

      if (activeFilters.isNotEmpty) {
        _isInBackground = true;
        logger.i("Switching to background");

        // Persist filters so the background service can restore subscriptions
        // if revived from a dead state (e.g. FCM wake after app is killed).
        try {
          final filterMaps = activeFilters.map((f) => f.toMap()).toList();
          await prefs.setString(
            SharedPreferencesKeys.backgroundFilters.value,
            jsonEncode(filterMaps),
          );
        } catch (e) {
          logger.e('Failed to persist background filters: $e');
        }

        subscriptionManager.suspend();

        // Transfer active subscriptions to background service
        final backgroundService = ref.read(backgroundServiceProvider);
        await backgroundService.setForegroundStatus(false);
        logger.i(
            "Transferring ${activeFilters.length} active filters to background service");
        backgroundService.subscribe(activeFilters);
      } else {
        _isInBackground = true;
        // Still suspend: a pending relay sync retry must not re-open a REQ
        // while the background service owns connectivity.
        subscriptionManager.suspend();
        logger.w("No active subscriptions to transfer to background service");
        // Clear any previously persisted filters to prevent stale subscriptions
        // on service revival
        await prefs.remove(SharedPreferencesKeys.backgroundFilters.value);
      }

      logger.i("Background transition complete");
    } catch (e) {
      logger.e("Error during background transition: $e");
    }
  }

  @Deprecated('Use SubscriptionManager instead.')
  void addSubscription(NostrFilter filter) {
    logger.w('LifecycleManager.addSubscription is deprecated. Use SubscriptionManager instead.');
    // No-op - subscriptions are now tracked by SubscriptionManager
  }

  void dispose() {
    _backgroundDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}

// Provider for the lifecycle manager
final lifecycleManagerProvider = Provider((ref) => LifecycleManager(ref));
