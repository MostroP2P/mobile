import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/storage_keys.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the highest `protocol_version` each Mostro node has ever been
/// *verified* to advertise, so a relay cannot walk a client back to an older
/// wire transport.
///
/// The client learns a node's transport from its kind-38385 info event. Two
/// guards already sit in front of that event: the signature must verify, and
/// the event must be newer than the one in use. Neither survives a restart —
/// `OpenOrdersRepository` holds the info event in memory only, so on a cold
/// start the first info event to arrive is accepted with nothing to compare
/// it against. A relay that withholds the current event, or replays a
/// genuinely signed one from before the operator migrated to v2, downgrades
/// the client for that whole session.
///
/// This store is the part that persists. It is deliberately monotonic: a
/// recorded version is never lowered, so once a node has been seen speaking
/// v2 no later event can make this client speak v1 to it again.
///
/// Keyed by node pubkey, so switching between Mostro instances keeps each
/// node's history separate.
class ProtocolVersionStore {
  final SharedPreferencesAsync _prefs;

  /// Node pubkey -> highest verified `protocol_version`. Authoritative once
  /// [init] has run; persistence is a write-behind mirror of it.
  Map<String, int> _versions = {};

  bool _initialized = false;

  ProtocolVersionStore(this._prefs);

  /// Loads persisted versions into memory. Must complete before the first
  /// [versionFor] call for the ratchet to apply on a cold start; a store that
  /// failed to load simply knows nothing and reports null.
  Future<void> init() async {
    _versions = await _load();
    _initialized = true;
  }

  bool get isInitialized => _initialized;

  /// Highest verified protocol version seen for [pubkey], or null if this
  /// client has never verified an info event from that node.
  int? versionFor(String pubkey) => _versions[pubkey];

  /// Records [version] for [pubkey], keeping the higher of the two.
  ///
  /// Call this only for a version parsed from an info event whose signature
  /// has been verified — an unverified event is a relay's claim, not the
  /// node's, and recording it would poison the ratchet permanently.
  ///
  /// Returns true when the stored value changed.
  bool record(String pubkey, int version) {
    if (pubkey.isEmpty) return false;
    // Guard against a malformed tag ratcheting the store to a value no
    // resolver would honour anyway.
    if (version < 1) {
      logger.w('Ignoring non-positive protocol_version $version for $pubkey');
      return false;
    }

    final current = _versions[pubkey];
    if (current != null && current >= version) {
      if (current > version) {
        logger.w(
          'Node $pubkey advertised protocol_version $version but has been '
          'verified at $current before; keeping $current',
        );
      }
      return false;
    }

    _versions[pubkey] = version;
    logger.i('Recorded protocol_version $version for node $pubkey');
    _persist();
    return true;
  }

  /// Drops everything this store knows. Intended for an explicit "forget this
  /// device's history" action, not for routine flows — clearing it reopens the
  /// downgrade window the ratchet exists to close.
  Future<void> clear() async {
    _versions = {};
    try {
      await _prefs.remove(SharedPreferencesKeys.nodeProtocolVersions.value);
    } catch (e) {
      logger.e('Failed to clear protocol versions: $e');
    }
  }

  /// Memory is authoritative, so a failed write costs at most the ratchet's
  /// memory of this node across a restart — never a wrong value.
  void _persist() {
    _prefs
        .setString(
          SharedPreferencesKeys.nodeProtocolVersions.value,
          jsonEncode(_versions),
        )
        .catchError(
          (e) => logger.e('Failed to persist protocol versions: $e'),
        );
  }

  Future<Map<String, int>> _load() async {
    try {
      final json = await _prefs.getString(
        SharedPreferencesKeys.nodeProtocolVersions.value,
      );
      if (json == null) return {};

      final decoded = jsonDecode(json);
      if (decoded is! Map) return {};

      final result = <String, int>{};
      decoded.forEach((key, value) {
        if (key is! String || key.isEmpty) return;
        // Tolerate anything a previous version (or a corrupted write) left
        // behind: a malformed entry is dropped, never allowed to throw and
        // take the whole ratchet down with it.
        final version = value is int
            ? value
            : value is String
                ? int.tryParse(value)
                : null;
        if (version != null && version >= 1) {
          result[key] = version;
        }
      });
      return result;
    } catch (e) {
      logger.e('Failed to load protocol versions: $e');
      return {};
    }
  }
}

final protocolVersionStoreProvider = Provider<ProtocolVersionStore>((ref) {
  return ProtocolVersionStore(ref.watch(sharedPreferencesProvider));
});
