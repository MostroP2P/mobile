import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

/// Reproduces the verification logic used in CommunityRepository.
/// Returns true only if the event ID matches the content hash AND
/// the Schnorr signature is valid for that ID.
bool verifyRawEvent(Map<String, dynamic> event) {
  final id = event['id'] as String?;
  final pubkey = event['pubkey'] as String?;
  final sig = event['sig'] as String?;
  final createdAt = event['created_at'] as int?;
  final kind = event['kind'] as int?;
  final content = event['content'] as String? ?? '';
  final tags = event['tags'] as List<dynamic>?;

  if (id == null || pubkey == null || sig == null ||
      createdAt == null || kind == null) {
    return false;
  }

  // Step 1: Verify event ID matches content hash (NIP-01)
  final serialized =
      jsonEncode([0, pubkey, createdAt, kind, tags ?? [], content]);
  final computedId = sha256.convert(utf8.encode(serialized)).toString();
  if (computedId != id) return false;

  // Step 2: Verify Schnorr signature over the event ID
  return NostrKeyPairs.verify(pubkey, id, sig);
}

void main() {
  group('CommunityRepository event verification', () {
    test('accepts valid kind 0 event', () {
      final keyPair = NostrUtils.generateKeyPair();
      final event = NostrEvent.fromPartialData(
        kind: 0,
        content: '{"name":"Test","about":"A test node"}',
        keyPairs: keyPair,
        tags: [
          ['p', 'deadbeef'],
        ],
      );

      expect(verifyRawEvent(event.toMap()), isTrue);
    });

    test('accepts valid kind 38385 event with empty content', () {
      final keyPair = NostrUtils.generateKeyPair();
      final event = NostrEvent.fromPartialData(
        kind: 38385,
        content: '',
        keyPairs: keyPair,
        tags: [
          ['y', 'mostro'],
          ['fiat_currencies_accepted', 'USD,EUR'],
          ['fee', '0.01'],
        ],
      );

      expect(verifyRawEvent(event.toMap()), isTrue);
    });

    test('rejects event with tampered content', () {
      final keyPair = NostrUtils.generateKeyPair();
      final event = NostrEvent.fromPartialData(
        kind: 0,
        content: '{"name":"Real Node"}',
        keyPairs: keyPair,
      );

      final tampered = Map<String, dynamic>.from(event.toMap());
      tampered['content'] = '{"name":"Spoofed Node"}';

      // ID no longer matches the tampered content
      expect(verifyRawEvent(tampered), isFalse);
    });

    test('rejects event with tampered pubkey', () {
      final keyPair = NostrUtils.generateKeyPair();
      final otherKeyPair = NostrUtils.generateKeyPair();
      final event = NostrEvent.fromPartialData(
        kind: 0,
        content: '{"name":"Real"}',
        keyPairs: keyPair,
      );

      final tampered = Map<String, dynamic>.from(event.toMap());
      tampered['pubkey'] = otherKeyPair.public;

      expect(verifyRawEvent(tampered), isFalse);
    });

    test('rejects event with forged id and signature', () {
      final keyPair = NostrUtils.generateKeyPair();
      final attackerKeyPair = NostrUtils.generateKeyPair();

      final original = NostrEvent.fromPartialData(
        kind: 0,
        content: '{"name":"Real"}',
        keyPairs: keyPair,
      );

      // Attacker creates a new event with spoofed content but original pubkey
      final spoofedContent = '{"name":"Spoofed"}';
      final originalMap = original.toMap();
      final serialized = jsonEncode([
        0,
        originalMap['pubkey'],
        originalMap['created_at'],
        originalMap['kind'],
        originalMap['tags'] ?? [],
        spoofedContent,
      ]);
      final forgedId = sha256.convert(utf8.encode(serialized)).toString();
      // Attacker signs with their own key
      final forgedSig = attackerKeyPair.sign(forgedId);

      final tampered = Map<String, dynamic>.from(originalMap);
      tampered['content'] = spoofedContent;
      tampered['id'] = forgedId;
      tampered['sig'] = forgedSig;

      // Signature was made by attacker, not by the original pubkey
      expect(verifyRawEvent(tampered), isFalse);
    });

    test('handles event with null content as empty string', () {
      final keyPair = NostrUtils.generateKeyPair();
      final event = NostrEvent.fromPartialData(
        kind: 38385,
        content: '',
        keyPairs: keyPair,
        tags: [
          ['y', 'mostro'],
        ],
      );

      final rawMap = event.toMap();
      // Simulate relay sending null content (edge case)
      rawMap.remove('content');

      // Should still work — defaults to empty string
      expect(verifyRawEvent(rawMap), isTrue);
    });
  });
}
