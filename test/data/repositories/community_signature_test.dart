import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/repositories/community_repository.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

void main() {
  late CommunityRepository repository;

  setUp(() {
    repository = CommunityRepository();
  });

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

      expect(repository.verifyEvent(event.toMap()), isTrue);
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

      expect(repository.verifyEvent(event.toMap()), isTrue);
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

      expect(repository.verifyEvent(tampered), isFalse);
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

      expect(repository.verifyEvent(tampered), isFalse);
    });

    test('rejects event with forged id and signature', () {
      final keyPair = NostrUtils.generateKeyPair();
      final attackerKeyPair = NostrUtils.generateKeyPair();

      final original = NostrEvent.fromPartialData(
        kind: 0,
        content: '{"name":"Real"}',
        keyPairs: keyPair,
      );

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
      final forgedSig = attackerKeyPair.sign(forgedId);

      final tampered = Map<String, dynamic>.from(originalMap);
      tampered['content'] = spoofedContent;
      tampered['id'] = forgedId;
      tampered['sig'] = forgedSig;

      expect(repository.verifyEvent(tampered), isFalse);
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
      rawMap.remove('content');

      expect(repository.verifyEvent(rawMap), isTrue);
    });
  });
}
