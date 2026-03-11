import 'package:flutter_test/flutter_test.dart';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/features/key_manager/key_derivator.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

void main() {
  // Use valid keys from NIP-06 test vectors
  const validMnemonic =
      'leader monkey parrot ring guide accident before fence cannon height naive bean';
  final keyDerivator = KeyDerivator(Config.keyDerivationPath);
  final extendedPrivKey = keyDerivator.extendedKeyFromMnemonic(validMnemonic);
  final senderPrivKey = keyDerivator.derivePrivateKey(extendedPrivKey, 1);
  final receiverPrivKey = keyDerivator.derivePrivateKey(extendedPrivKey, 2);
  final receiverPublicKey = keyDerivator.privateToPublicKey(receiverPrivKey);
  final senderPublicKey = keyDerivator.privateToPublicKey(senderPrivKey);
  final wrongPrivKey = keyDerivator.derivePrivateKey(extendedPrivKey, 3);

  group('p2pWrap / p2pUnwrap round-trip', () {
    test('wraps and unwraps a text message correctly', () async {
      // Compute shared key from both sides
      final senderSharedKey =
          NostrUtils.computeSharedKey(senderPrivKey, receiverPublicKey);
      final receiverSharedKey =
          NostrUtils.computeSharedKey(receiverPrivKey, senderPublicKey);

      // Both should be the same
      expect(senderSharedKey.public, equals(receiverSharedKey.public));

      // Create inner event (kind 1)
      final innerEvent = NostrEvent.fromPartialData(
        keyPairs: NostrKeyPairs(private: senderPrivKey),
        content: 'Hello admin, I need help with my dispute',
        kind: 1,
        tags: [
          ["p", senderSharedKey.public],
        ],
      );

      // Wrap with p2pWrap
      final wrappedEvent = await innerEvent.p2pWrap(
        NostrKeyPairs(private: senderPrivKey),
        senderSharedKey.public,
      );

      // Unwrap with receiver's shared key
      final unwrapped = await wrappedEvent.p2pUnwrap(receiverSharedKey);

      // Verify content matches
      expect(unwrapped.content,
          equals('Hello admin, I need help with my dispute'));
      // Verify sender pubkey matches
      expect(unwrapped.pubkey, equals(senderPublicKey));
      // Verify kind 1
      expect(unwrapped.kind, equals(1));
    });

    test('unwrap fails with wrong key', () async {
      final sharedKey =
          NostrUtils.computeSharedKey(senderPrivKey, receiverPublicKey);
      final wrongSharedKey =
          NostrUtils.computeSharedKey(wrongPrivKey, receiverPublicKey);

      final innerEvent = NostrEvent.fromPartialData(
        keyPairs: NostrKeyPairs(private: senderPrivKey),
        content: 'Secret message',
        kind: 1,
        tags: [
          ["p", sharedKey.public],
        ],
      );

      final wrappedEvent = await innerEvent.p2pWrap(
        NostrKeyPairs(private: senderPrivKey),
        sharedKey.public,
      );

      // Unwrap with wrong key should throw
      expect(
        () => wrappedEvent.p2pUnwrap(wrongSharedKey),
        throwsA(isA<Exception>()),
      );
    });

    test('wrapped event has kind 1059 and correct p tag', () async {
      final sharedKey =
          NostrUtils.computeSharedKey(senderPrivKey, receiverPublicKey);

      final innerEvent = NostrEvent.fromPartialData(
        keyPairs: NostrKeyPairs(private: senderPrivKey),
        content: 'Test message',
        kind: 1,
        tags: [
          ["p", sharedKey.public],
        ],
      );

      final wrappedEvent = await innerEvent.p2pWrap(
        NostrKeyPairs(private: senderPrivKey),
        sharedKey.public,
      );

      // Wrapper should be kind 1059
      expect(wrappedEvent.kind, equals(1059));

      // p tag should point to shared key pubkey
      final pTag = wrappedEvent.tags?.firstWhere(
        (tag) => tag.isNotEmpty && tag[0] == 'p',
        orElse: () => [],
      );
      expect(pTag, isNotNull);
      expect(pTag!.length, greaterThanOrEqualTo(2));
      expect(pTag[1], equals(sharedKey.public));

      // Wrapper pubkey should be ephemeral (different from sender)
      expect(wrappedEvent.pubkey, isNot(equals(senderPublicKey)));
    });

    test('plain text content round-trips (no JSON wrapper needed)', () async {
      final sharedKey =
          NostrUtils.computeSharedKey(senderPrivKey, receiverPublicKey);
      final receiverSharedKey =
          NostrUtils.computeSharedKey(receiverPrivKey, senderPublicKey);

      // Content is plain text (dispute chat style)
      const plainText = 'This is a dispute message with no JSON wrapping';

      final innerEvent = NostrEvent.fromPartialData(
        keyPairs: NostrKeyPairs(private: senderPrivKey),
        content: plainText,
        kind: 1,
        tags: [
          ["p", sharedKey.public],
        ],
      );

      final wrapped = await innerEvent.p2pWrap(
        NostrKeyPairs(private: senderPrivKey),
        sharedKey.public,
      );

      final unwrapped = await wrapped.p2pUnwrap(receiverSharedKey);

      expect(unwrapped.content, equals(plainText));
    });
  });
}
