import 'dart:convert';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

/// Replicates the Mostro signing scheme (SHA-256 hex digest, Schnorr-verified)
/// for asserting the tuple signatures.
bool verifyMostroSig(String pubkey, String message, String sig) {
  final hash = hex.encode(sha256.convert(utf8.encode(message)).bytes);
  return NostrKeyPairs.verify(pubkey, hash, sig);
}

void main() {
  group('MostroMessage.wrapNip44 (protocol v2)', () {
    late NostrKeyPairs tradeKey;
    late NostrKeyPairs masterKey;
    late NostrKeyPairs mostroKey; // stands in for the node / recipient

    setUp(() {
      tradeKey = NostrUtils.generateKeyPair();
      masterKey = NostrUtils.generateKeyPair();
      mostroKey = NostrUtils.generateKeyPair();
    });

    test('reputation mode: kind-14 event round-trips with identity proof',
        () async {
      final message = MostroMessage(
        action: Action.fiatSent,
        id: 'order-1',
        requestId: 7,
      );

      final event = await message.wrapNip44(
        tradeKey: tradeKey,
        recipientPubKey: mostroKey.public,
        masterKey: masterKey,
        keyIndex: 5,
      );

      // Event shape: kind 14, authored by the trade key, p-tagged to the node.
      expect(event.kind, 14);
      expect(event.pubkey, tradeKey.public);
      expect(
        event.tags!.any((t) => t[0] == 'p' && t[1] == mostroKey.public),
        isTrue,
      );

      // Node decrypts with its private key + the event author (trade key).
      final content = await NostrUtils.decryptNIP44DirectEvent(
        event,
        mostroKey.private,
        expectedAuthor: tradeKey.public,
      );
      final tuple = jsonDecode(content) as List;
      expect(tuple.length, 3);

      // Element 0: the message with version 2, decodes to the original.
      final messageMap = tuple[0] as Map<String, dynamic>;
      expect(messageMap['order']['version'], 2);
      final decoded = MostroMessage.fromJson(messageMap);
      expect(decoded.action, Action.fiatSent);
      expect(decoded.id, 'order-1');

      // Element 1: trade-key signature over the exact message JSON.
      final messageJson = jsonEncode(messageMap);
      expect(tuple[1], isNotNull);
      expect(verifyMostroSig(tradeKey.public, messageJson, tuple[1] as String),
          isTrue);

      // Element 2: identity proof = [identityPubkey, sig over domain payload].
      final proof = tuple[2] as List;
      expect(proof[0], masterKey.public);
      final domain =
          'mostro-transport-v2-identity:${tradeKey.public}:$messageJson';
      expect(verifyMostroSig(masterKey.public, domain, proof[1] as String),
          isTrue);
    });

    test('full-privacy mode: tradeSig and identityProof are null', () async {
      final message = MostroMessage(
        action: Action.fiatSent,
        id: 'order-2',
        requestId: 9,
      );

      final event = await message.wrapNip44(
        tradeKey: tradeKey,
        recipientPubKey: mostroKey.public,
        masterKey: null,
      );

      expect(event.kind, 14);
      expect(event.pubkey, tradeKey.public);

      final content = await NostrUtils.decryptNIP44DirectEvent(
        event,
        mostroKey.private,
        expectedAuthor: tradeKey.public,
      );
      final tuple = jsonDecode(content) as List;
      expect(tuple.length, 3);
      expect((tuple[0] as Map)['order']['version'], 2);
      expect(tuple[1], isNull);
      expect(tuple[2], isNull);

      final decoded = MostroMessage.fromJson(tuple[0] as Map<String, dynamic>);
      expect(decoded.action, Action.fiatSent);
      expect(decoded.id, 'order-2');
    });
  });
}
