import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/features/restore/restore_manager.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

/// Regression tests for the restore receive path covering both transports:
/// v1 gift wrap (kind 1059) and v2 NIP-44 direct (kind 14). The node is the
/// sender; the client decrypts with its temporary restore trade key.
void main() {
  group('decodeRestoreMessage (restore transport branch)', () {
    late NostrKeyPairs tempTradeKey;
    late NostrKeyPairs mostroKey;

    // A restore response as Mostro sends it: tuple [message, signature?].
    final restoreTuple = jsonEncode([
      {
        'restore': {
          'version': 1,
          'action': 'restore',
          'payload': {
            'restore_data': {'orders': [], 'disputes': []},
          },
        },
      },
      null,
    ]);

    setUp(() {
      tempTradeKey = NostrUtils.generateKeyPair();
      mostroKey = NostrUtils.generateKeyPair();
    });

    /// Builds a v2 (kind 14) reply authored by the node toward the temp key.
    Future<NostrEvent> buildV2Reply(String tuple) async {
      final encrypted = await NostrUtils.encryptNIP44(
        tuple,
        mostroKey.private,
        tempTradeKey.public,
      );
      return NostrEvent.fromPartialData(
        kind: 14,
        content: encrypted,
        keyPairs: mostroKey,
        tags: [
          ['p', tempTradeKey.public],
        ],
        createdAt: DateTime.now(),
      );
    }

    test('v1 gift wrap (kind 1059) decodes to the restore message', () async {
      final event = await NostrUtils.createNIP59Event(
        restoreTuple,
        tempTradeKey.public,
        mostroKey.private,
      );

      expect(event.kind, 1059);
      final data = await decodeRestoreMessage(
        event,
        tempTradeKey,
        mostroKey.public,
      );
      expect(data.containsKey('restore'), isTrue);
    });

    test('v2 NIP-44 direct (kind 14) decodes to the restore message', () async {
      final event = await buildV2Reply(restoreTuple);

      expect(event.kind, 14);
      expect(event.pubkey, mostroKey.public);
      final data = await decodeRestoreMessage(
        event,
        tempTradeKey,
        mostroKey.public,
      );
      expect(data.containsKey('restore'), isTrue);
    });

    test('v1 and v2 decode to identical message maps', () async {
      final v1 = await NostrUtils.createNIP59Event(
        restoreTuple,
        tempTradeKey.public,
        mostroKey.private,
      );
      final v2 = await buildV2Reply(restoreTuple);

      final d1 = await decodeRestoreMessage(v1, tempTradeKey, mostroKey.public);
      final d2 = await decodeRestoreMessage(v2, tempTradeKey, mostroKey.public);

      expect(d2, equals(d1));
    });

    test('v2 reply from an unexpected author is rejected', () async {
      final imposter = NostrUtils.generateKeyPair();
      final encrypted = await NostrUtils.encryptNIP44(
        restoreTuple,
        imposter.private,
        tempTradeKey.public,
      );
      final event = NostrEvent.fromPartialData(
        kind: 14,
        content: encrypted,
        keyPairs: imposter,
        tags: [
          ['p', tempTradeKey.public],
        ],
        createdAt: DateTime.now(),
      );

      // expectedAuthor is the real node; the imposter-authored event must fail.
      expect(
        () => decodeRestoreMessage(event, tempTradeKey, mostroKey.public),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
