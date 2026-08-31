import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';
import 'package:nip44/nip44.dart';

/// Every NIP-44 encrypt/decrypt recomputed the conversation key — one EC
/// scalar multiplication (5-30 ms of BigInt math on a mid phone) plus HKDF —
/// even though it is constant per (our key, their key) pair: the node
/// conversation for a session and each chat conversation reuse the same pair
/// for every message. The key is now cached and injected through the nip44
/// fork's `customConversationKey`. Callers receive a defensive copy, so a
/// caller writing into the returned buffer cannot corrupt the cache.
void main() {
  const alicePriv =
      'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890';
  const bobPriv =
      '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
  final alicePub = NostrKeyPairs(private: alicePriv).public;
  final bobPub = NostrKeyPairs(private: bobPriv).public;

  test('the conversation key is cached after the first derivation', () {
    NostrUtils.clearConversationKeyCache();

    final first = NostrUtils.conversationKeyFor(alicePriv, bobPub);
    final second = NostrUtils.conversationKeyFor(alicePriv, bobPub);

    expect(NostrUtils.conversationKeyCacheContains(alicePriv, bobPub), isTrue,
        reason: 'repeat messages on the same conversation must not repeat '
            'ECDH + HKDF');
    expect(second, equals(first));
    // Callers get a defensive copy, never the cached buffer itself: a caller
    // mutating the returned bytes must not corrupt the cache process-wide.
    expect(identical(first, second), isFalse);
  });

  test('mutating a returned key does not corrupt the cache', () async {
    NostrUtils.clearConversationKeyCache();

    final leaked = NostrUtils.conversationKeyFor(alicePriv, bobPub);
    leaked.fillRange(0, leaked.length, 0);

    final cipher = await NostrUtils.encryptNIP44('hola', alicePriv, bobPub);
    expect(await Nip44.decryptMessage(cipher, bobPriv, alicePub), 'hola');
  });

  test('cached key == what the library derives on its own', () {
    final cached = NostrUtils.conversationKeyFor(alicePriv, bobPub);
    final plain = Nip44.deriveConversationKey(
        Nip44.computeSharedSecret(alicePriv, bobPub));

    expect(cached, equals(plain));
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

  test('library encrypts -> cached path decrypts', () async {
    const msg = 'ciphertext produced WITHOUT the cache';
    final cipher = await Nip44.encryptMessage(msg, alicePriv, bobPub);

    expect(await NostrUtils.decryptNIP44(cipher, bobPriv, alicePub), msg);
  });

  test('cached path encrypts -> library decrypts', () async {
    const msg = 'ciphertext produced WITH the cache';
    final cipher = await NostrUtils.encryptNIP44(msg, alicePriv, bobPub);

    expect(await Nip44.decryptMessage(cipher, bobPriv, alicePub), msg);
  });

  test('a tampered payload is still rejected (MAC check survives)', () async {
    final cipher = await NostrUtils.encryptNIP44('hola', alicePriv, bobPub);
    final chars = cipher.split('');
    final mid = chars.length ~/ 2;
    chars[mid] = chars[mid] == 'A' ? 'B' : 'A';

    await expectLater(
      NostrUtils.decryptNIP44(chars.join(), bobPriv, alicePub),
      throwsA(isA<Exception>()),
    );
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

    expect(NostrUtils.conversationKeyCacheContains(alicePriv, bobPub), isFalse,
        reason: 'a cache:false derivation must not be stored for reuse');
    expect(NostrUtils.conversationKeyFor(alicePriv, bobPub), equals(uncached));
  });

  test('evictConversationKeysFor drops every entry for that private key', () {
    NostrUtils.clearConversationKeyCache();

    NostrUtils.conversationKeyFor(alicePriv, bobPub);
    NostrUtils.conversationKeyFor(alicePriv, alicePub);
    NostrUtils.conversationKeyFor(bobPriv, alicePub);

    NostrUtils.evictConversationKeysFor(alicePriv);

    // Alice's entries were dropped, Bob's survived.
    expect(
        NostrUtils.conversationKeyCacheContains(alicePriv, bobPub), isFalse);
    expect(
        NostrUtils.conversationKeyCacheContains(alicePriv, alicePub), isFalse);
    expect(NostrUtils.conversationKeyCacheContains(bobPriv, alicePub), isTrue);
  });

  test('clearConversationKeyCache empties the cache (account wipe path)', () {
    NostrUtils.conversationKeyFor(alicePriv, bobPub);
    expect(NostrUtils.conversationKeyCacheSize, greaterThan(0));

    NostrUtils.clearConversationKeyCache();

    expect(NostrUtils.conversationKeyCacheSize, 0);
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
