import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

/// Builds a kind-38385 info event of the shape the daemon publishes
/// (empty content, everything in tags), signed by [keyPair].
NostrEvent _infoEvent(NostrKeyPairs keyPair, {String protocolVersion = '2'}) {
  return NostrEvent.fromPartialData(
    kind: 38385,
    content: '',
    keyPairs: keyPair,
    tags: [
      ['d', 'info'],
      ['y', 'mostro'],
      ['protocol_version', protocolVersion],
    ],
  );
}

void main() {
  group('NostrUtils.isValidEventSignature', () {
    test('accepts a genuinely signed event', () {
      final event = _infoEvent(NostrUtils.generateKeyPair());

      expect(NostrUtils.isValidEventSignature(event), isTrue);
    });

    test('accepts a signed event with non-empty content and no tags', () {
      final event = NostrEvent.fromPartialData(
        kind: 1,
        content: 'plain note',
        keyPairs: NostrUtils.generateKeyPair(),
        tags: const [],
      );

      expect(NostrUtils.isValidEventSignature(event), isTrue);
    });

    test('rejects tampered tags — the id no longer matches the content', () {
      final signed = _infoEvent(NostrUtils.generateKeyPair());

      // Flip protocol_version 2 -> 1 while keeping the original id/sig.
      final tampered = NostrEvent(
        id: signed.id,
        sig: signed.sig,
        pubkey: signed.pubkey,
        kind: signed.kind,
        content: signed.content,
        createdAt: signed.createdAt,
        tags: const [
          ['d', 'info'],
          ['y', 'mostro'],
          ['protocol_version', '1'],
        ],
      );

      expect(NostrUtils.isValidEventSignature(tampered), isFalse);
    });

    test('rejects tampered content', () {
      final signed = NostrEvent.fromPartialData(
        kind: 1,
        content: 'original',
        keyPairs: NostrUtils.generateKeyPair(),
        tags: const [],
      );

      final tampered = NostrEvent(
        id: signed.id,
        sig: signed.sig,
        pubkey: signed.pubkey,
        kind: signed.kind,
        content: 'spoofed',
        createdAt: signed.createdAt,
        tags: signed.tags,
      );

      expect(NostrUtils.isValidEventSignature(tampered), isFalse);
    });

    // This is the case NostrEvent.isVerified() lets through: it only checks
    // the Schnorr signature against the event's self-declared id, so a genuine
    // (id, sig, pubkey) triple lifted from one event and pasted onto a
    // different payload passes it. Recomputing the id is what catches it.
    test('rejects a genuine signature triple pasted onto a different payload',
        () {
      final keyPair = NostrUtils.generateKeyPair();
      final genuine = _infoEvent(keyPair);

      final forged = NostrEvent(
        id: genuine.id,
        sig: genuine.sig,
        pubkey: genuine.pubkey,
        kind: 38385,
        content: '',
        createdAt: genuine.createdAt,
        tags: const [
          ['d', 'info'],
          ['y', 'mostro'],
          ['protocol_version', '1'],
        ],
      );

      // The weaker check the rest of the codebase reaches for is fooled...
      expect(forged.isVerified(), isTrue);
      // ...while recomputing the id is not.
      expect(NostrUtils.isValidEventSignature(forged), isFalse);
    });

    test('rejects an event signed by a different key', () {
      final signed = _infoEvent(NostrUtils.generateKeyPair());
      final impostor = NostrUtils.generateKeyPair();

      final swapped = NostrEvent(
        id: signed.id,
        sig: signed.sig,
        pubkey: impostor.public,
        kind: signed.kind,
        content: signed.content,
        createdAt: signed.createdAt,
        tags: signed.tags,
      );

      expect(NostrUtils.isValidEventSignature(swapped), isFalse);
    });

    test('rejects an event with a malformed signature', () {
      final signed = _infoEvent(NostrUtils.generateKeyPair());

      final broken = NostrEvent(
        id: signed.id,
        sig: 'not-a-signature',
        pubkey: signed.pubkey,
        kind: signed.kind,
        content: signed.content,
        createdAt: signed.createdAt,
        tags: signed.tags,
      );

      expect(NostrUtils.isValidEventSignature(broken), isFalse);
    });

    test('rejects an unsigned event', () {
      final signed = _infoEvent(NostrUtils.generateKeyPair());

      final unsigned = NostrEvent(
        id: signed.id,
        sig: null,
        pubkey: signed.pubkey,
        kind: signed.kind,
        content: signed.content,
        createdAt: signed.createdAt,
        tags: signed.tags,
      );

      expect(NostrUtils.isValidEventSignature(unsigned), isFalse);
    });

    test('rejects an event with no id', () {
      final signed = _infoEvent(NostrUtils.generateKeyPair());

      final idless = NostrEvent(
        id: null,
        sig: signed.sig,
        pubkey: signed.pubkey,
        kind: signed.kind,
        content: signed.content,
        createdAt: signed.createdAt,
        tags: signed.tags,
      );

      expect(NostrUtils.isValidEventSignature(idless), isFalse);
    });
  });
}
