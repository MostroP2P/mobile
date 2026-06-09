import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager_provider.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';

/// Safety net for relay connectivity.
///
/// Periodically checks whether any relay is alive. When none are (cold start
/// where discovered relays never connect, or every discovered relay dropped at
/// runtime), it engages the defensive bootstrap relays and re-establishes the
/// subscriptions so the app keeps receiving events.
///
/// All recovery is additive (it never disconnects), reusing the proven
/// `subscribeAll()` path. Engaging bootstrap on a false positive only costs an
/// idle socket, so the check is intentionally biased toward acting.
class RelayHealthMonitor {
  final Ref ref;
  Timer? _timer;
  bool _recovering = false;

  RelayHealthMonitor(this.ref) {
    _timer = Timer.periodic(Config.relayDiscoveryTimeout, (_) => _check());
    ref.onDispose(() => _timer?.cancel());
  }

  /// Runs a single health check synchronously. Exposed for tests so the
  /// periodic timer does not need to be awaited.
  @visibleForTesting
  Future<void> checkNow() => _check();

  Future<void> _check() async {
    if (_recovering) return;

    final nostrService = ref.read(nostrServiceProvider);
    if (!nostrService.isInitialized) return;
    if (nostrService.liveRelayCount > 0) return;

    _recovering = true;
    try {
      logger.w('No live relays detected; engaging bootstrap relays');
      await nostrService.ensureBootstrapConnectivity();

      // Re-issue subscriptions so they reach the newly connected relays
      // (additive init does not replay REQs to relays added afterwards).
      final subscriptionManager = ref.read(subscriptionManagerProvider);
      subscriptionManager.subscribeAll();

      // Re-establish relay-list discovery so the app can recover its relays.
      final mostroPubkey = ref.read(settingsProvider).mostroPublicKey;
      if (mostroPubkey.isNotEmpty) {
        subscriptionManager.subscribeToMostroRelayList(mostroPubkey);
      }
    } catch (e, stackTrace) {
      logger.e('Relay health recovery failed',
          error: e, stackTrace: stackTrace);
    } finally {
      _recovering = false;
    }
  }
}

final relayHealthMonitorProvider = Provider<RelayHealthMonitor>(
  (ref) => RelayHealthMonitor(ref),
);
