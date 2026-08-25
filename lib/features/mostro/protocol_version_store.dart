import 'dart:async';
import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/storage_keys.dart';
import 'package:mostro_mobile/features/mostro/mostro_instance.dart';
import 'package:mostro_mobile/features/mostro/transport.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the most recent `protocol_version` each Mostro node has been
/// *verified* to assert, so a relay cannot walk a client back to an older wire
/// transport by serving an older event.
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
/// This store is the part that persists, and what it persists is the *signed
/// timestamp* alongside the version. A relay picks which events it serves but
/// cannot mint one or re-date one, so "newer than anything this client has
/// verified" is precisely the property it cannot forge. A replayed
/// pre-migration v1 event loses against a recorded v2; a genuinely newer signed
/// v1 event — an operator rolling back, which mostrod 0.18.x still supports —
/// wins, and the client follows the node instead of being partitioned from it.
/// See [anchoredProtocolVersion] for the comparison itself.
///
/// Keyed by node pubkey, so switching between Mostro instances keeps each
/// node's history separate.
class ProtocolVersionStore {
  final SharedPreferencesAsync _prefs;

  /// Node pubkey -> most recent verified assertion. Authoritative once [init]
  /// has run; persistence is a write-behind mirror of it.
  Map<String, VersionAssertion> _versions = {};

  bool _initialized = false;

  /// Tail of the write chain. Every mutation of the persisted key is appended
  /// here so writes land in call order.
  ///
  /// `SharedPreferencesAsync` holds no Dart-side cache: each call goes
  /// straight to platform storage and concurrent calls complete in whatever
  /// order the platform picks. Without this chain a `setString` issued before
  /// a `clear()` could land after it and resurrect the cleared map, or an
  /// older snapshot could overwrite a newer one — the anchor only ever moves
  /// forward in memory, but its disk mirror would not.
  Future<void> _writes = Future<void>.value();

  ProtocolVersionStore(this._prefs);

  /// Completes when every write queued so far has finished. Useful to flush
  /// before shutdown, and the only way a caller can observe durability —
  /// [record] returns as soon as memory is updated.
  Future<void> get pendingWrites => _writes;

  /// Appends [op] to the write chain and returns when it has run. Failures are
  /// logged and swallowed so one bad write cannot poison every later one.
  Future<void> _enqueueWrite(
    Future<void> Function() op,
    String description,
  ) {
    final queued = _writes.then((_) => op()).catchError(
      (Object e) => logger.e('Failed to $description: $e'),
    );
    _writes = queued;
    return queued;
  }

  /// Loads persisted versions into memory. Must complete before the first
  /// [versionFor] call for the ratchet to apply on a cold start; a store that
  /// failed to load simply knows nothing and reports null.
  ///
  /// Merges rather than replaces. A `SubscriptionManager` can exist before this
  /// runs — `RelaysNotifier` builds one of its own during bootstrap, and every
  /// instance feeds the info-event stream into [record] — so entries may
  /// already have been anchored in memory. Overwriting them would drop that
  /// evidence, and the next snapshot would carry the loss to disk: an anchor
  /// that forgets is the one thing this store must not be.
  Future<void> init() async {
    final loaded = await _load();
    final early = _versions;
    _versions = loaded;
    _initialized = true;

    var merged = false;
    early.forEach((pubkey, assertion) {
      final current = _versions[pubkey];
      if (current == null || _supersedes(assertion, current)) {
        _versions[pubkey] = assertion;
        merged = true;
      }
    });

    // Only when something survived the load, so a normal cold start still
    // costs no write. This is also the first write allowed through, so what
    // lands on disk is the union rather than either half.
    if (merged) _persist();
  }

  bool get isInitialized => _initialized;

  /// The most recent verified assertion for [pubkey], or null if this client
  /// has never verified an info event from that node.
  VersionAssertion? assertionFor(String pubkey) => _versions[pubkey];

  /// The version of [assertionFor], for callers that do not need its date.
  int? versionFor(String pubkey) => _versions[pubkey]?.version;

  /// Records [version] for [pubkey] as asserted at [createdAt], keeping
  /// whichever assertion is the more recent evidence.
  ///
  /// [createdAt] must be the `created_at` of the info event that carried the
  /// version, not the time of the call: the point of storing it is that it is
  /// signed, and a wall-clock stamp would let a relay advance the anchor just
  /// by delivering an old event late.
  ///
  /// Call this only for a version parsed from an info event whose signature
  /// has been verified — an unverified event is a relay's claim, not the
  /// node's, and recording it would poison the anchor.
  ///
  /// Returns true when the stored assertion changed. That includes a same
  /// version re-asserted more recently: the date is what later replays are
  /// measured against, so it has to move forward too.
  bool record(String pubkey, int version, DateTime? createdAt) {
    if (pubkey.isEmpty) return false;
    // Guard against a malformed tag anchoring the store to a value no resolver
    // would honour anyway.
    if (version < 1) {
      logger.w('Ignoring non-positive protocol_version $version for $pubkey');
      return false;
    }

    final incoming = VersionAssertion(version, createdAt);
    final current = _versions[pubkey];
    if (current != null && !_supersedes(incoming, current)) {
      if (current.version != version) {
        logger.w(
          'Node $pubkey asserted protocol_version $version at $createdAt, '
          'which does not postdate the verified assertion of ${current.version} '
          'at ${current.createdAt}; keeping ${current.version}',
        );
      }
      return false;
    }

    _versions[pubkey] = incoming;
    logger.i(
      'Recorded protocol_version $version for node $pubkey '
      'asserted at $createdAt',
    );
    // Nothing reaches disk before [init] has merged what is already there.
    // A snapshot taken now would be of a map that has not seen storage yet,
    // and writing it would erase every node this device had verified in an
    // earlier session — the load that was going to rescue them has not run.
    if (_initialized) _persist();
    return true;
  }

  /// Whether [incoming] is the better evidence of what a node speaks than
  /// [current], using the same rule [anchoredProtocolVersion] resolves with:
  /// the more recent signed assertion wins, and a tie — or an assertion that
  /// cannot be dated — falls back to the higher version.
  bool _supersedes(VersionAssertion incoming, VersionAssertion current) {
    final incomingAt = incoming.createdAt;
    final currentAt = current.createdAt;
    if (incomingAt != null && currentAt != null) {
      if (incomingAt.isAfter(currentAt)) return true;
      if (currentAt.isAfter(incomingAt)) return false;
    }
    return incoming.version > current.version;
  }

  /// Drops everything this store knows. Intended for an explicit "forget this
  /// device's history" action, not for routine flows — clearing it reopens the
  /// downgrade window the anchor exists to close.
  Future<void> clear() {
    _versions = {};
    return _enqueueWrite(
      () => _prefs.remove(SharedPreferencesKeys.nodeProtocolVersions.value),
      'clear protocol versions',
    );
  }

  /// Memory is authoritative, so a failed write costs at most this node's
  /// anchor across a restart — never a wrong value.
  ///
  /// The snapshot is encoded here, at call time, and the write is queued: what
  /// reaches disk is the map as it stood when the caller asked, applied in the
  /// order the callers asked.
  void _persist() {
    final snapshot = jsonEncode(
      _versions.map((pubkey, assertion) => MapEntry(pubkey, _encode(assertion))),
    );
    unawaited(
      _enqueueWrite(
        () => _prefs.setString(
          SharedPreferencesKeys.nodeProtocolVersions.value,
          snapshot,
        ),
        'persist protocol versions',
      ),
    );
  }

  /// `{"v": version, "t": secondsSinceEpoch}`, with `t` omitted for an
  /// assertion that carried no usable date. Seconds rather than milliseconds
  /// to match the `created_at` this came from.
  Map<String, Object> _encode(VersionAssertion assertion) {
    final createdAt = assertion.createdAt;
    return {
      'v': assertion.version,
      if (createdAt != null)
        't': createdAt.millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond,
    };
  }

  /// The inverse of [_encode], or null for anything that is not a usable
  /// entry. Entries are dropped rather than repaired: an assertion whose shape
  /// this build does not recognise cannot be dated, and something that cannot
  /// be dated is not evidence.
  VersionAssertion? _decode(Object? value) {
    if (value is! Map) return null;

    final version = _asInt(value['v']);
    if (version == null || version < 1) return null;

    final seconds = _asInt(value['t']);
    return VersionAssertion(
      version,
      seconds == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              seconds * Duration.millisecondsPerSecond,
              isUtc: true,
            ),
    );
  }

  int? _asInt(Object? value) => value is int
      ? value
      : value is String
          ? int.tryParse(value)
          : null;

  Future<Map<String, VersionAssertion>> _load() async {
    try {
      final json = await _prefs.getString(
        SharedPreferencesKeys.nodeProtocolVersions.value,
      );
      if (json == null) return {};

      final decoded = jsonDecode(json);
      if (decoded is! Map) return {};

      final result = <String, VersionAssertion>{};
      decoded.forEach((key, value) {
        if (key is! String || key.isEmpty) return;
        // Tolerate anything a previous version (or a corrupted write) left
        // behind: a malformed entry is dropped, never allowed to throw and
        // take the whole anchor down with it.
        final assertion = _decode(value);
        if (assertion != null) result[key] = assertion;
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

/// The protocol version to use when talking to the currently connected node:
/// what it advertises now, anchored against the most recent assertion it has
/// been verified to make.
///
/// Single resolution point on purpose. The send path and the receive
/// subscription must never disagree about which transport is in play — a
/// client listening on kind 14 while publishing kind 1059 is partitioned from
/// the node, and the attacker-controlled half of that split is the forgeable
/// one. Every caller reads this instead of reaching for
/// `mostroInstance?.protocolVersion` directly.
///
/// Returns null only when the node has never been heard from and nothing is
/// remembered; [resolveTransport] maps that to [kDefaultTransport].
///
/// A verified info event that carries no `protocol_version` tag reads as
/// [kLegacyProtocolVersion], not as "unknown" — see that constant for why the
/// two cases must stay distinct.
int? anchoredProtocolVersionFor(Ref ref) {
  try {
    final infoEvent = ref.read(orderRepositoryProvider).mostroInstance;
    final mostroPubkey = ref.read(settingsProvider).mostroPublicKey;
    final remembered =
        ref.read(protocolVersionStoreProvider).assertionFor(mostroPubkey);
    return anchoredProtocolVersion(_advertisedBy(infoEvent), remembered);
  } catch (e) {
    // Null resolves to the safe default rather than to v1, so failing to read
    // the node's state cannot be turned into a downgrade.
    logger.w('Failed to resolve anchored protocol version: $e');
    return null;
  }
}

/// What [infoEvent] actually asserts about its transport, and when, in the
/// three states the tag can be in.
///
/// - No info event, or a tag that is present but unusable → null. Both are an
///   absence of evidence, and [resolveTransport] maps null to the safe
///   default. A malformed value must land here rather than in the legacy
///   branch: reading `protocol_version=abc` as v1 would pair the client with
///   gift wrap against a node that may well be speaking NIP-44.
/// - Tag absent entirely → [kLegacyProtocolVersion]. Silence from a verified
///   event is a legacy daemon asserting v1.
/// - Tag present and parseable → that version, whatever it is;
///   [resolveTransport] decides what to do with one it does not speak.
///
/// The assertion carries the event's signed `created_at`, which is what
/// [anchoredProtocolVersion] weighs it against the remembered one with.
VersionAssertion? _advertisedBy(NostrEvent? infoEvent) {
  if (infoEvent == null) return null;

  final parsed = infoEvent.protocolVersion;
  if (parsed != null) return VersionAssertion(parsed, infoEvent.createdAt);

  if (infoEvent.advertisesProtocolVersion) {
    logger.w(
      'Node ${infoEvent.pubkey} advertises an unparseable protocol_version; '
      'treating the transport as unknown rather than legacy',
    );
    return null;
  }
  return VersionAssertion(kLegacyProtocolVersion, infoEvent.createdAt);
}
