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
}
