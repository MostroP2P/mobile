import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

/// A kind-0 metadata event as a node publishes it.
NostrEvent _metadata(NostrKeyPairs keys, Map<String, dynamic> profile) {
  return NostrEvent.fromPartialData(
    kind: 0,
    content: jsonEncode(profile),
    keyPairs: keys,
    tags: const [],
  );
}

/// Keeps the genuine (id, sig, pubkey) triple and swaps the content — exactly
/// what a relay can do for free, and exactly what `isVerified()` misses.
NostrEvent _contentSwapped(NostrEvent genuine, Map<String, dynamic> profile) {
  return NostrEvent(
    id: genuine.id,
    sig: genuine.sig,
    pubkey: genuine.pubkey,
    kind: genuine.kind,
    content: jsonEncode(profile),
    createdAt: genuine.createdAt,
    tags: genuine.tags,
  );
}

void main() {
  late NostrKeyPairs nodeKeys;

  setUp(() => nodeKeys = NostrUtils.generateKeyPair());

  group('kind-0 node metadata verification', () {
    test('a genuine metadata event verifies', () {
      final event = _metadata(nodeKeys, {
        'name': 'mostro',
        'picture': 'https://example.test/a.png',
      });

      expect(NostrUtils.isValidEventSignature(event), isTrue);
    });

    // The gap MM-015 names. This is the event a relay serves to make a node it
    // controls read as a trusted one in the node picker: the signature is real
    // and belongs to the node, but it was never made over this content.
    test('a content swap keeping the genuine signature is rejected', () {
      final genuine = _metadata(nodeKeys, {'name': 'mostro'});
      final swapped = _contentSwapped(genuine, {
        'name': 'mostro (official)',
        'picture': 'https://attacker.test/logo.png',
      });

      expect(
        swapped.isVerified(),
        isTrue,
        reason: 'isVerified only checks the sig against the declared id, '
            'which is why it cannot be the gate here',
      );
      expect(
        NostrUtils.isValidEventSignature(swapped),
        isFalse,
        reason: 'recomputing the id binds the signature to the content',
      );
    });

    test('a tag swap keeping the genuine signature is rejected', () {
      final genuine = _metadata(nodeKeys, {'name': 'mostro'});
      final retagged = NostrEvent(
        id: genuine.id,
        sig: genuine.sig,
        pubkey: genuine.pubkey,
        kind: genuine.kind,
        content: genuine.content,
        createdAt: genuine.createdAt,
        tags: const [
          ['k', 'sell'],
        ],
      );

      expect(retagged.isVerified(), isTrue);
      expect(NostrUtils.isValidEventSignature(retagged), isFalse);
    });

    test('an event signed by someone else is rejected', () {
      final attacker = NostrUtils.generateKeyPair();
      final genuine = _metadata(nodeKeys, {'name': 'mostro'});
      final forged = NostrEvent(
        id: genuine.id,
        sig: genuine.sig,
        pubkey: attacker.public,
        kind: genuine.kind,
        content: genuine.content,
        createdAt: genuine.createdAt,
        tags: genuine.tags,
      );

      expect(NostrUtils.isValidEventSignature(forged), isFalse);
    });
  });
}
