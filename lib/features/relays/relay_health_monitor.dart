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

  /// Exponential backoff between recovery attempts while an outage persists:
  /// each attempt is a full CLOSE+REQ fan-out, and re-running it on every
  /// 6-second tick against relays that stay down is a resubscription storm.
  static const Duration initialBackoff = Config.relayDiscoveryTimeout;
  static const Duration maxBackoff = Duration(minutes: 5);
  Duration _backoff = initialBackoff;
  Duration? _nextAttemptAfter;

  /// Monotonic time source for the backoff deadline. The wall clock is not
  /// usable here: a backward correction (manual change or an NTP sync during
  /// the outage) would park the deadline in the future and suppress recovery
  /// for far longer than [maxBackoff].
  final Stopwatch _elapsed = Stopwatch()..start();

  RelayHealthMonitor(this.ref) {
    _timer = Timer.periodic(Config.relayDiscoveryTimeout, (_) => _check());
    ref.onDispose(() => _timer?.cancel());
  }

  /// Runs a single health check synchronously. Exposed for tests so the
  /// periodic timer does not need to be awaited; [elapsed] injects the
  /// monotonic clock reading.
  @visibleForTesting
  Future<void> checkNow({Duration? elapsed}) => _check(elapsed: elapsed);

  /// Re-arms the backoff so the next check recovers immediately.
  ///
  /// A healthy tick is the only other reset, and it cannot fire while the
  /// outage lasts. After a long stretch in the background with no network the
  /// backoff sits at [maxBackoff], so without this a foreground return with
  /// working network could wait up to five minutes for the safety net to try
  /// again. Called from the foreground transition.
  void resetBackoff() {
    _backoff = initialBackoff;
    _nextAttemptAfter = null;
  }

  Future<void> _check({Duration? elapsed}) async {
    if (_recovering) return;

    final nostrService = ref.read(nostrServiceProvider);
    if (!nostrService.isInitialized) return;

    // Only relays from the operating set (discovered + user, which never
    // includes bootstrap) count as healthy. A live bootstrap-only socket must
    // not mask a dead discovered-relay layer, otherwise recovery would stop
    // while the app is surviving on bootstrap connectivity alone.
    final operatingRelays = ref.read(settingsProvider).relays.toSet();
    final hasLiveOperatingRelay =
        nostrService.connectedRelays.any(operatingRelays.contains);
    if (hasLiveOperatingRelay) {
      // Healthy: arm the next outage for an immediate first attempt. Note this
      // exit is unreachable while `settings.relays` is empty (cold start before
      // kind-10002 discovery): there is no operating relay to be alive, so the
      // backoff only grows. That is why [resetBackoff] exists.
      resetBackoff();
      return;
    }

    final tick = elapsed ?? _elapsed.elapsed;
    if (_nextAttemptAfter != null && tick < _nextAttemptAfter!) return;
    _nextAttemptAfter = tick + _backoff;
    final doubled = _backoff * 2;
    _backoff = doubled > maxBackoff ? maxBackoff : doubled;

    _recovering = true;
    try {
      logger.w('No live operating relay; engaging bootstrap relays');
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
