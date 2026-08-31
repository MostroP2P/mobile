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
}
