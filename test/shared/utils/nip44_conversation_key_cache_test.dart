import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

/// Every NIP-44 encrypt/decrypt recomputed the conversation key — one EC
/// scalar multiplication (5-30 ms of BigInt math on a mid phone) plus HKDF —
/// even though it is constant per (our key, their key) pair: the node
/// conversation for a session and each chat conversation reuse the same pair
/// for every message. The key is now cached and injected through the nip44
/// fork's `customConversationKey`.
void main() {
  const alicePriv =
      'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890';
  const bobPriv =
      '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
  final alicePub = NostrKeyPairs(private: alicePriv).public;
  final bobPub = NostrKeyPairs(private: bobPriv).public;

  test('the conversation key is computed once per key pair', () {
    final first = NostrUtils.conversationKeyFor(alicePriv, bobPub);
    final second = NostrUtils.conversationKeyFor(alicePriv, bobPub);

    expect(identical(first, second), isTrue,
        reason: 'repeat messages on the same conversation must not repeat '
            'ECDH + HKDF');
  });

  test('different pairs derive different keys', () {
    final ab = NostrUtils.conversationKeyFor(alicePriv, bobPub);
    final ba = NostrUtils.conversationKeyFor(bobPriv, alicePub);
    final aa = NostrUtils.conversationKeyFor(alicePriv, alicePub);

    // ECDH is symmetric: both directions of one conversation agree...
    expect(ab, equals(ba));
    // ...and a different pair does not.
    expect(aa, isNot(equals(ab)));
  });

  test('encrypt/decrypt roundtrip works through the cached key', () async {
    const content = 'mensaje de prueba nip44';

    final cipher = await NostrUtils.encryptNIP44(content, alicePriv, bobPub);
    // Prime + reuse: decrypt goes through the cache on the other side.
    final plain = await NostrUtils.decryptNIP44(cipher, bobPriv, alicePub);

    expect(plain, content);
  });

  test('two messages on the same conversation decrypt correctly', () async {
    final c1 = await NostrUtils.encryptNIP44('uno', alicePriv, bobPub);
    final c2 = await NostrUtils.encryptNIP44('dos', alicePriv, bobPub);

    expect(await NostrUtils.decryptNIP44(c1, bobPriv, alicePub), 'uno');
    expect(await NostrUtils.decryptNIP44(c2, bobPriv, alicePub), 'dos');
  });

  test('cache: false derives without retaining one-shot key material', () {
    NostrUtils.clearConversationKeyCache();

    final uncached =
        NostrUtils.conversationKeyFor(alicePriv, bobPub, cache: false);
    final later = NostrUtils.conversationKeyFor(alicePriv, bobPub);

    // Equal derivation, but the first call must not have populated the cache.
    expect(later, equals(uncached));
    expect(identical(later, uncached), isFalse,
        reason: 'a cache:false derivation must not be stored for reuse');
  });

  test('evictConversationKeysFor drops every entry for that private key', () {
    NostrUtils.clearConversationKeyCache();

    final aliceToBob = NostrUtils.conversationKeyFor(alicePriv, bobPub);
    final aliceToSelf = NostrUtils.conversationKeyFor(alicePriv, alicePub);
    final bobToAlice = NostrUtils.conversationKeyFor(bobPriv, alicePub);

    NostrUtils.evictConversationKeysFor(alicePriv);

    // Alice's entries were recomputed (new instances), Bob's survived.
    expect(
        identical(NostrUtils.conversationKeyFor(alicePriv, bobPub), aliceToBob),
        isFalse);
    expect(
        identical(
            NostrUtils.conversationKeyFor(alicePriv, alicePub), aliceToSelf),
        isFalse);
    expect(
        identical(NostrUtils.conversationKeyFor(bobPriv, alicePub), bobToAlice),
        isTrue);
  });

  test('NIP-59 wrapping leaves no ephemeral wrapper keys in the cache',
      () async {
    NostrUtils.clearConversationKeyCache();

    final wrap = await NostrUtils.createNIP59Event(
      'contenido de prueba',
      bobPub,
      alicePriv,
    );
    await NostrUtils.decryptNIP59Event(wrap, bobPriv);

    // The seal encrypt uses a one-shot wrapper private key and the wrap
    // decrypt uses its one-shot wrapper pubkey; neither may be cached.
    expect(
        NostrUtils.conversationKeyCacheContains(bobPriv, wrap.pubkey), isFalse,
        reason: 'the ephemeral wrapper conversation must not be cached');

    // Only the stable sender<->recipient conversations may remain: the rumor
    // encrypt (alice side) and the rumor decrypt (bob side).
    expect(NostrUtils.conversationKeyCacheSize, 2,
        reason: 'only stable sender<->recipient entries may be cached');
  });
}
