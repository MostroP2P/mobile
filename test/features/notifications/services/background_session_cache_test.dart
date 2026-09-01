import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/peer.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/notifications/services/background_session_cache.dart';

/// The background isolate used to open the database, construct and init a
/// KeyManager (secure-storage reads) and re-derive every session's chat keys
/// TWICE per incoming event. Session state only changes when this isolate
/// writes it (or on a fresh service start), so a small TTL cache with
/// explicit invalidation removes all of that per-event work.
void main() {
  Session session(String orderId, {String? peerPubkey}) {
    final s = Session(
      masterKey: NostrKeyPairs(
          private:
              '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef'),
      tradeKey: NostrKeyPairs(
          private:
              'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890'),
      keyIndex: 0,
      fullPrivacy: false,
      startTime: DateTime.now(),
    );
    s.orderId = orderId;
    if (peerPubkey != null) {
      s.peer = Peer(publicKey: peerPubkey);
    }
    return s;
  }

  test('the loader runs once for repeated reads inside the TTL', () async {
    var loads = 0;
    final cache = BackgroundSessionCache();
    Future<List<Session>> loader() async {
      loads++;
      return [session('o1')];
    }

    final a = await cache.sessions(loader);
    final b = await cache.sessions(loader);

    expect(loads, 1);
    expect(identical(a, b), isTrue);
  });

  test('invalidate forces the next read to reload', () async {
    var loads = 0;
    final cache = BackgroundSessionCache();
    Future<List<Session>> loader() async {
      loads++;
      return [session('o$loads')];
    }

    await cache.sessions(loader);
    cache.invalidate();
    final after = await cache.sessions(loader);

    expect(loads, 2);
    expect(after.single.orderId, 'o2');
  });

  test('the TTL expires the cached sessions', () async {
    var loads = 0;
    final cache = BackgroundSessionCache(ttl: const Duration(milliseconds: 1));
    Future<List<Session>> loader() async {
      loads++;
      return [session('o1')];
    }

    await cache.sessions(loader);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await cache.sessions(loader);

    expect(loads, 2);
  });

  test('chat keys are derived once per shared key', () {
    const peer =
        'aa11111111111111111111111111111111111111111111111111111111111111';
    final cache = BackgroundSessionCache();
    final shared = session('o1', peerPubkey: peer).sharedKey!;

    final first = cache.chatKeysFor(shared);
    final second = cache.chatKeysFor(shared);

    expect(identical(first, second), isTrue,
        reason: 'ChatKeys derivation costs two EC multiplications');
    expect(first.sign.public, isNotEmpty);
  });

  test('a concurrent burst shares one in-flight load', () async {
    var loads = 0;
    final cache = BackgroundSessionCache();
    Future<List<Session>> loader() async {
      loads++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return [session('o1')];
    }

    final results = await Future.wait([
      cache.sessions(loader),
      cache.sessions(loader),
      cache.sessions(loader),
    ]);

    expect(loads, 1);
    expect(results, everyElement(hasLength(1)));
  });

  test('a failed session load is not cached', () async {
    var loads = 0;
    final cache = BackgroundSessionCache();
    Future<List<Session>> loader() async {
      loads++;
      if (loads == 1) throw StateError('transient database error');
      return [session('o1')];
    }

    await expectLater(cache.sessions(loader), throwsStateError);
    final after = await cache.sessions(loader);

    expect(loads, 2,
        reason: 'a transient failure must not be cached as an empty session '
            'list, or every event in the TTL window is silently discarded');
    expect(after.single.orderId, 'o1');
  });

  test('a missing Mostro pubkey is cached for the TTL', () async {
    var loads = 0;
    final cache = BackgroundSessionCache();
    Future<String?> loader() async {
      loads++;
      return null;
    }

    expect(await cache.mostroPubkey(loader), isNull);
    expect(await cache.mostroPubkey(loader), isNull);

    expect(loads, 1,
        reason: 'an absent pubkey is a valid answer; re-reading settings on '
            'every kind-14 event is the work this cache exists to avoid');
  });

  test('a failed pubkey load is not cached', () async {
    var loads = 0;
    final cache = BackgroundSessionCache();
    Future<String?> loader() async {
      loads++;
      if (loads == 1) throw StateError('secure storage unavailable');
      return 'npubdeadbeef';
    }

    await expectLater(cache.mostroPubkey(loader), throwsStateError);

    expect(await cache.mostroPubkey(loader), 'npubdeadbeef');
    expect(loads, 2);
  });

  /// The wiring concern behind the cache: a kind-14 event is matched by the
  /// K_sign public key derived from the session's shared key, so a cache hit
  /// must resolve the same session a fresh load would; and the peer written by
  /// _maybeUpdateSessionWithPeer must be visible to the very next event, which
  /// is what its invalidate() call buys.
  test('cached sessions resolve the event author, and a peer write is visible '
      'after invalidate', () async {
    const peer =
        'aa11111111111111111111111111111111111111111111111111111111111111';
    var loads = 0;
    String? storedPeer;
    final cache = BackgroundSessionCache();
    Future<List<Session>> loader() async {
      loads++;
      return [session('o1', peerPubkey: storedPeer)];
    }

    Future<Session?> resolveByAuthor(String author) async {
      for (final s in await cache.sessions(loader)) {
        final shared = s.sharedKey;
        if (shared == null) continue;
        if (cache.chatKeysFor(shared).sign.public == author) return s;
      }
      return null;
    }

    // No peer yet: nothing to match a chat author against.
    expect(await resolveByAuthor('cc33'), isNull);
    expect(loads, 1);

    // _maybeUpdateSessionWithPeer writes the peer, then invalidates.
    storedPeer = peer;
    cache.invalidate();

    final signPublic = cache
        .chatKeysFor((await cache.sessions(loader)).single.sharedKey!)
        .sign
        .public;
    expect(loads, 2, reason: 'the peer write must be observed');

    expect((await resolveByAuthor(signPublic))?.orderId, 'o1');
    expect((await resolveByAuthor(signPublic))?.peer?.publicKey, peer);
    expect(await resolveByAuthor('cc33'), isNull);
    expect(loads, 2, reason: 'all three lookups served from one load');
  });
}
