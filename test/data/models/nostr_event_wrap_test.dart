import 'dart:convert';

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

  /// Reproduces the retired pre-migration wire format (1-layer gift wrap:
  /// ephemeral key, NIP-44 to the shared key pubkey, kind 1059) so the
  /// p2pUnwrap path that reads stored history stays covered.
  Future<NostrEvent> legacyWrap(
    NostrEvent innerEvent,
    String receiverPubkey,
  ) async {
    final ephemeralKeyPair = NostrUtils.generateKeyPair();
    final encryptedContent = await NostrUtils.encryptNIP44(
      jsonEncode(innerEvent.toMap()),
      ephemeralKeyPair.private,
      receiverPubkey,
    );
    return NostrEvent.fromPartialData(
      kind: 1059,
      content: encryptedContent,
      keyPairs: ephemeralKeyPair,
      tags: [
        ["p", receiverPubkey],
      ],
    );
  }

  group('p2pUnwrap (legacy stored history)', () {
    test('unwraps a legacy-wrapped text message correctly', () async {
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

      final wrappedEvent = await legacyWrap(innerEvent, senderSharedKey.public);

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

      final wrappedEvent = await legacyWrap(innerEvent, sharedKey.public);

      // Unwrap with wrong key should throw
      expect(
        () => wrappedEvent.p2pUnwrap(wrongSharedKey),
        throwsA(isA<Exception>()),
      );
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

      final wrapped = await legacyWrap(innerEvent, sharedKey.public);

      final unwrapped = await wrapped.p2pUnwrap(receiverSharedKey);

      expect(unwrapped.content, equals(plainText));
    });
  });
}
