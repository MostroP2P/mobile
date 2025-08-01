import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';

/// Mostro daemon health status
enum MostroHealthStatus {
  healthy, // Heartbeat received within expected timeframe
  warning, // Heartbeat delayed but within tolerance
  offline, // No heartbeat for extended period
  unknown, // Initial state or error condition
}

/// Mostro daemon heartbeat information
class MostroHeartbeat {
  final String daemonPubkey;
  final DateTime lastSeen;
  final String? mostroVersion;
  final String? mostroCommitHash;
  final int? fee;
  final int? expirationHours;
  final int? holdInvoiceExpirationWindow;
  final String? lndNodeAlias;
  final String? lndVersion;
  final List<String> relays;
  final MostroHealthStatus status;

  MostroHeartbeat({
    required this.daemonPubkey,
    required this.lastSeen,
    this.mostroVersion,
    this.mostroCommitHash,
    this.fee,
    this.expirationHours,
    this.holdInvoiceExpirationWindow,
    this.lndNodeAlias,
    this.lndVersion,
    this.relays = const [],
    required this.status,
  });

  /// Calculate health status based on last seen timestamp
  static MostroHealthStatus calculateStatus(DateTime lastSeen) {
    final now = DateTime.now();
    final timeSinceLastSeen = now.difference(lastSeen);

    // Healthy: heartbeat within last 2 minutes
    if (timeSinceLastSeen.inMinutes < 2) {
      return MostroHealthStatus.healthy;
    }

    // Warning: heartbeat within last 5 minutes
    if (timeSinceLastSeen.inMinutes < 5) {
      return MostroHealthStatus.warning;
    }

    // Offline: no heartbeat for 5+ minutes
    return MostroHealthStatus.offline;
  }

  MostroHeartbeat copyWith({
    String? daemonPubkey,
    DateTime? lastSeen,
    String? mostroVersion,
    String? mostroCommitHash,
    int? fee,
    int? expirationHours,
    int? holdInvoiceExpirationWindow,
    String? lndNodeAlias,
    String? lndVersion,
    List<String>? relays,
    MostroHealthStatus? status,
  }) {
    return MostroHeartbeat(
      daemonPubkey: daemonPubkey ?? this.daemonPubkey,
      lastSeen: lastSeen ?? this.lastSeen,
      mostroVersion: mostroVersion ?? this.mostroVersion,
      mostroCommitHash: mostroCommitHash ?? this.mostroCommitHash,
      fee: fee ?? this.fee,
      expirationHours: expirationHours ?? this.expirationHours,
      holdInvoiceExpirationWindow:
          holdInvoiceExpirationWindow ?? this.holdInvoiceExpirationWindow,
      lndNodeAlias: lndNodeAlias ?? this.lndNodeAlias,
      lndVersion: lndVersion ?? this.lndVersion,
      relays: relays ?? this.relays,
      status: status ?? this.status,
    );
  }
}

/// Monitors Mostro daemon heartbeat events for health status
class MostroHeartbeatMonitor extends StateNotifier<MostroHeartbeat?> {
  final Ref ref;
  final Logger _logger = Logger();

  StreamSubscription<NostrEvent>? _heartbeatSubscription;
  StreamSubscription<NostrEvent>? _relayListSubscription;
  Timer? _statusCheckTimer;

  // Track multiple daemon instances if needed
  final Map<String, MostroHeartbeat> _daemonHeartbeats = {};
  String? _primaryDaemonPubkey;

  MostroHeartbeatMonitor(this.ref) : super(null) {
    _startMonitoring();
  }

  /// Start monitoring daemon heartbeat events
  void _startMonitoring() {
    _logger.i('Starting Mostro daemon heartbeat monitoring');

    try {
      _subscribeToHeartbeatEvents();
      _subscribeToRelayListEvents();
      _startStatusCheckTimer();
    } catch (e) {
      _logger.e('Failed to start heartbeat monitoring: $e');
    }
  }

  /// Subscribe to Mostro daemon info events (kind 38383)
  void _subscribeToHeartbeatEvents() {
    final nostrService = ref.read(nostrServiceProvider);

    // Create filter for Mostro daemon info events
    final filter = NostrFilter(
      kinds: [38383], // Mostro daemon info events
      since: DateTime.now().subtract(const Duration(minutes: 10)),
    );

    final request = NostrRequest(filters: [filter]);
    final stream = nostrService.subscribeToEvents(request);

    _heartbeatSubscription = stream.listen(
      (event) => _handleHeartbeatEvent(event),
      onError: (error) {
        _logger.w('Heartbeat subscription error: $error');
      },
      cancelOnError: false,
    );

    _logger.d('Subscribed to Mostro daemon heartbeat events (kind 38383)');
  }

  /// Subscribe to Mostro daemon relay list events (kind 10002)
  void _subscribeToRelayListEvents() {
    final nostrService = ref.read(nostrServiceProvider);

    // Create filter for relay list events
    final filter = NostrFilter(
      kinds: [10002], // Relay list events
      since: DateTime.now().subtract(const Duration(minutes: 10)),
    );

    final request = NostrRequest(filters: [filter]);
    final stream = nostrService.subscribeToEvents(request);

    _relayListSubscription = stream.listen(
      (event) => _handleRelayListEvent(event),
      onError: (error) {
        _logger.w('Relay list subscription error: $error');
      },
      cancelOnError: false,
    );

    _logger.d('Subscribed to Mostro daemon relay list events (kind 10002)');
  }

  /// Handle incoming heartbeat event (kind 38383)
  void _handleHeartbeatEvent(NostrEvent event) {
    try {
      // Verify this is a Mostro daemon info event
      final zTag = event.tags?.firstWhere(
        (tag) => tag.length >= 2 && tag[0] == 'z' && tag[1] == 'info',
        orElse: () => [],
      );

      if (zTag == null || zTag.isEmpty) {
        return; // Not a Mostro info event
      }

      // Extract daemon pubkey from 'd' tag
      final dTag = event.tags?.firstWhere(
        (tag) => tag.length >= 2 && tag[0] == 'd',
        orElse: () => [],
      );

      if (dTag == null || dTag.isEmpty) {
        _logger.w('Mostro heartbeat event missing daemon pubkey (d tag)');
        return;
      }

      final daemonPubkey = dTag[1];
      final createdAt = event.createdAt;
      if (createdAt == null) {
        _logger.w('Heartbeat event missing timestamp');
        return;
      }
      // Convert Unix timestamp to DateTime
      final lastSeen =
          DateTime.fromMillisecondsSinceEpoch(createdAt.millisecondsSinceEpoch);

      // Parse event content for daemon metadata
      Map<String, dynamic>? content;
      try {
        final eventContent = event.content;
        content = (eventContent != null && eventContent.isNotEmpty)
            ? jsonDecode(eventContent)
            : null;
      } catch (e) {
        _logger.w('Failed to parse heartbeat event content: $e');
      }

      // Create or update heartbeat info
      final existingHeartbeat = _daemonHeartbeats[daemonPubkey];
      final newHeartbeat = MostroHeartbeat(
        daemonPubkey: daemonPubkey,
        lastSeen: lastSeen,
        mostroVersion: content?['mostro_version']?.toString(),
        mostroCommitHash: content?['mostro_commit_hash']?.toString(),
        fee: content?['fee'] as int?,
        expirationHours: content?['expiration_hours'] as int?,
        holdInvoiceExpirationWindow:
            content?['hold_invoice_expiration_window'] as int?,
        lndNodeAlias: content?['lnd_node_alias']?.toString(),
        lndVersion: content?['lnd_version']?.toString(),
        relays: existingHeartbeat?.relays ?? [],
        status: MostroHeartbeat.calculateStatus(lastSeen),
      );

      _daemonHeartbeats[daemonPubkey] = newHeartbeat;

      // Set as primary daemon if first one or if this one is healthier
      if (_primaryDaemonPubkey == null ||
          newHeartbeat.status.index <
              (_daemonHeartbeats[_primaryDaemonPubkey]?.status.index ?? 3)) {
        _primaryDaemonPubkey = daemonPubkey;
        state = newHeartbeat;
      }

      _logger.d(
          'Updated heartbeat for daemon $daemonPubkey: ${newHeartbeat.status}');
    } catch (e) {
      _logger.w('Error processing heartbeat event: $e');
    }
  }

  /// Handle incoming relay list event (kind 10002)
  void _handleRelayListEvent(NostrEvent event) {
    try {
      final daemonPubkey = event.pubkey;
      final createdAt = event.createdAt;
      if (createdAt == null) return;
      final lastSeen =
          DateTime.fromMillisecondsSinceEpoch(createdAt.millisecondsSinceEpoch);

      // Extract relay URLs from 'r' tags
      final relays = event.tags
              ?.where(
                (tag) => tag.length >= 2 && tag[0] == 'r',
              )
              .map((tag) => tag[1])
              .toList() ??
          [];

      // Update existing heartbeat with relay info
      final existingHeartbeat = _daemonHeartbeats[daemonPubkey];
      if (existingHeartbeat != null) {
        final updatedHeartbeat = existingHeartbeat.copyWith(
          relays: relays,
          lastSeen: lastSeen.isAfter(existingHeartbeat.lastSeen)
              ? lastSeen
              : existingHeartbeat.lastSeen,
        );

        _daemonHeartbeats[daemonPubkey] = updatedHeartbeat;

        if (_primaryDaemonPubkey == daemonPubkey) {
          state = updatedHeartbeat;
        }
      } else {
        // Create new heartbeat entry with relay info
        final newHeartbeat = MostroHeartbeat(
          daemonPubkey: daemonPubkey,
          lastSeen: lastSeen,
          relays: relays,
          status: MostroHeartbeat.calculateStatus(lastSeen),
        );

        _daemonHeartbeats[daemonPubkey] = newHeartbeat;

        if (_primaryDaemonPubkey == null) {
          _primaryDaemonPubkey = daemonPubkey;
          state = newHeartbeat;
        }
      }

      _logger.d(
          'Updated relay list for daemon $daemonPubkey: ${relays.length} relays');
    } catch (e) {
      _logger.w('Error processing relay list event: $e');
    }
  }

  /// Start periodic status check timer
  void _startStatusCheckTimer() {
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updateHealthStatus();
    });
  }

  /// Update health status for all tracked daemons
  void _updateHealthStatus() {
    bool stateUpdated = false;

    for (final entry in _daemonHeartbeats.entries) {
      final daemonPubkey = entry.key;
      final heartbeat = entry.value;

      final newStatus = MostroHeartbeat.calculateStatus(heartbeat.lastSeen);
      if (newStatus != heartbeat.status) {
        final updatedHeartbeat = heartbeat.copyWith(status: newStatus);
        _daemonHeartbeats[daemonPubkey] = updatedHeartbeat;

        if (_primaryDaemonPubkey == daemonPubkey) {
          state = updatedHeartbeat;
          stateUpdated = true;
        }

        _logger.i(
            'Daemon $daemonPubkey status changed: ${heartbeat.status} -> $newStatus');
      }
    }

    // If primary daemon is offline, try to find a healthier one
    if (!stateUpdated && _primaryDaemonPubkey != null) {
      final primaryHeartbeat = _daemonHeartbeats[_primaryDaemonPubkey];
      if (primaryHeartbeat?.status == MostroHealthStatus.offline) {
        _selectBestDaemon();
      }
    }
  }

  /// Select the healthiest daemon as primary
  void _selectBestDaemon() {
    MostroHeartbeat? bestHeartbeat;
    String? bestDaemonPubkey;

    for (final entry in _daemonHeartbeats.entries) {
      final heartbeat = entry.value;
      if (bestHeartbeat == null ||
          heartbeat.status.index < bestHeartbeat.status.index) {
        bestHeartbeat = heartbeat;
        bestDaemonPubkey = entry.key;
      }
    }

    if (bestDaemonPubkey != null && bestDaemonPubkey != _primaryDaemonPubkey) {
      _primaryDaemonPubkey = bestDaemonPubkey;
      state = bestHeartbeat;
      _logger.i(
          'Switched to healthier daemon: $bestDaemonPubkey (${bestHeartbeat?.status})');
    }
  }

  /// Get all tracked daemon heartbeats
  Map<String, MostroHeartbeat> getAllHeartbeats() {
    return Map.unmodifiable(_daemonHeartbeats);
  }

  /// Force refresh subscriptions (useful after connection recovery)
  void refreshSubscriptions() {
    _logger.i('Refreshing heartbeat subscriptions');

    _heartbeatSubscription?.cancel();
    _relayListSubscription?.cancel();

    _subscribeToHeartbeatEvents();
    _subscribeToRelayListEvents();
  }

  @override
  void dispose() {
    _logger.i('Disposing Mostro heartbeat monitor');

    _heartbeatSubscription?.cancel();
    _relayListSubscription?.cancel();
    _statusCheckTimer?.cancel();

    super.dispose();
  }
}

/// Provider for Mostro daemon heartbeat monitoring
final mostroHeartbeatProvider =
    StateNotifierProvider<MostroHeartbeatMonitor, MostroHeartbeat?>(
  (ref) => MostroHeartbeatMonitor(ref),
);

/// Provider for current daemon health status
final daemonHealthStatusProvider = Provider<MostroHealthStatus>((ref) {
  final heartbeat = ref.watch(mostroHeartbeatProvider);
  return heartbeat?.status ?? MostroHealthStatus.unknown;
});

/// Provider to check if daemon is healthy
final isDaemonHealthyProvider = Provider<bool>((ref) {
  final status = ref.watch(daemonHealthStatusProvider);
  return status == MostroHealthStatus.healthy;
});
