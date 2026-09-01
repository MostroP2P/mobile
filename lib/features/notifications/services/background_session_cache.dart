import 'package:dart_nostr/dart_nostr.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/shared/utils/chat_keys.dart';

/// Per-isolate cache for the background notification pipeline.
///
/// The background isolate used to open the database, construct and init a
/// KeyManager (secure-storage reads) and re-derive every session's chat keys
/// twice per incoming event. Session state only changes when this isolate
/// writes it (or on a fresh service start), so reads are memoized behind a
/// short TTL with explicit invalidation after local writes.
class BackgroundSessionCache {
  BackgroundSessionCache({this.ttl = const Duration(minutes: 2)});

  final Duration ttl;

  List<Session>? _sessions;
  DateTime? _loadedAt;
  Future<List<Session>>? _inFlight;
  String? _mostroPubkey;
  DateTime? _pubkeyLoadedAt;
  final Map<String, ChatKeys> _chatKeys = {};
  static const int _chatKeysLimit = 512;

  /// Sessions, loading through [loader] at most once per TTL window. A
  /// concurrent burst shares one in-flight load. A throwing loader caches
  /// nothing, so a transient failure does not blind the isolate for a whole
  /// TTL window.
  Future<List<Session>> sessions(
    Future<List<Session>> Function() loader,
  ) {
    final now = DateTime.now();
    final cached = _sessions;
    if (cached != null &&
        _loadedAt != null &&
        now.difference(_loadedAt!) < ttl) {
      return Future.value(cached);
    }
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    final load = () async {
      try {
        final loaded = await loader();
        _sessions = loaded;
        _loadedAt = DateTime.now();
        return loaded;
      } finally {
        _inFlight = null;
      }
    }();
    _inFlight = load;
    return load;
  }

  /// Node pubkey with the same TTL semantics. An absent pubkey is a valid
  /// answer and is cached like any other; a *failing* loader throws through,
  /// leaving nothing cached so the next event retries.
  Future<String?> mostroPubkey(Future<String?> Function() loader) async {
    final now = DateTime.now();
    if (_pubkeyLoadedAt != null && now.difference(_pubkeyLoadedAt!) < ttl) {
      return _mostroPubkey;
    }
    final loaded = await loader();
    _mostroPubkey = loaded;
    _pubkeyLoadedAt = DateTime.now();
    return loaded;
  }

  /// K_conv/K_sign pair per shared key (two EC multiplications each),
  /// derived once.
  ChatKeys chatKeysFor(NostrKeyPairs sharedKey) {
    final cached = _chatKeys[sharedKey.public];
    if (cached != null) return cached;
    final keys = ChatKeys.fromSharedKey(sharedKey);
    if (_chatKeys.length >= _chatKeysLimit) {
      _chatKeys.clear();
    }
    _chatKeys[sharedKey.public] = keys;
    return keys;
  }

  /// Drop the cached sessions/pubkey after a local write (peer update,
  /// settings change) so the next event sees fresh state. Chat keys are pure
  /// derivations and stay.
  void invalidate() {
    _sessions = null;
    _loadedAt = null;
    _mostroPubkey = null;
    _pubkeyLoadedAt = null;
  }
}
