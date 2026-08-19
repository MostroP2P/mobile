import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

/// Wraps [content] as mostrod does on the v1 transport: rumor -> seal signed
/// by the sender's identity key -> gift wrap under a throwaway ephemeral key.
Future<NostrEvent> _giftWrap({
  required NostrKeyPairs sender,
  required String recipientPubKey,
  String content = '[{"order":{"action":"pay-invoice"}}]',
}) {
  return NostrUtils.createNIP59Event(content, recipientPubKey, sender.private);
}

void main() {
  late NostrKeyPairs node;
  late NostrKeyPairs recipient;

  setUp(() {
    node = NostrUtils.generateKeyPair();
    recipient = NostrUtils.generateKeyPair();
  });

  group('decryptNIP59Event sender authentication', () {
    test('accepts a gift wrap sealed by the expected author', () async {
      final wrap = await _giftWrap(
        sender: node,
        recipientPubKey: recipient.public,
      );

      final rumor = await NostrUtils.decryptNIP59Event(
        wrap,
        recipient.private,
        expectedAuthor: node.public,
      );

      expect(rumor.content, '[{"order":{"action":"pay-invoice"}}]');
    });

    // The core of MM-001: the outer wrap is signed by a throwaway key and the
    // recipient's trade pubkey is public (it rides in the `p` tag of every
    // event addressed to them), so anyone who can see the relay traffic can
    // encrypt a well-formed gift wrap to a victim. Only the seal names the
    // real sender.
    test('rejects a gift wrap sealed by anyone else', () async {
      final attacker = NostrUtils.generateKeyPair();
      final forged = await _giftWrap(
        sender: attacker,
        recipientPubKey: recipient.public,
      );

      // It decrypts perfectly — nothing about the encryption is broken.
      await expectLater(
        NostrUtils.decryptNIP59Event(
          forged,
          recipient.private,
          expectedAuthor: node.public,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('rejects a seal whose signature does not verify', () async {
      final wrap = await _giftWrap(
        sender: node,
        recipientPubKey: recipient.public,
      );

      // Rebuild the wrap around a seal carrying the node's pubkey but a
      // signature that was never produced for it.
      final sealJson = jsonDecode(
        await NostrUtils.decryptNIP44(
          wrap.content!,
          recipient.private,
          wrap.pubkey,
        ),
      ) as Map<String, dynamic>;
      sealJson['sig'] = 'f' * 128;

      final tamperedWrap = await NostrUtils.createWrap(
        NostrUtils.generateKeyPair(),
        await NostrUtils.encryptNIP44(
          jsonEncode(sealJson),
          NostrUtils.generateKeyPair().private,
          recipient.public,
        ),
        recipient.public,
      );

      await expectLater(
        NostrUtils.decryptNIP59Event(
          tamperedWrap,
          recipient.private,
          expectedAuthor: node.public,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('still rejects a non-gift-wrap kind', () async {
      final notAWrap = NostrEvent.fromPartialData(
        kind: 1,
        content: 'hello',
        keyPairs: node,
        tags: const [],
      );

      await expectLater(
        NostrUtils.decryptNIP59Event(
          notAWrap,
          recipient.private,
          expectedAuthor: node.public,
        ),
        throwsArgumentError,
      );
    });
  });

  group('NostrEventExtensions.unWrap', () {
    test('round-trips a message from the expected author', () async {
      final wrap = await _giftWrap(
        sender: node,
        recipientPubKey: recipient.public,
        content: '[{"order":{"action":"fiat-sent-ok"}}]',
      );

      final rumor = await wrap.unWrap(
        recipient.private,
        expectedAuthor: node.public,
      );

      expect(rumor.content, contains('fiat-sent-ok'));
    });

    test('refuses a message from an impostor', () async {
      final attacker = NostrUtils.generateKeyPair();
      final forged = await _giftWrap(
        sender: attacker,
        recipientPubKey: recipient.public,
      );

      await expectLater(
        forged.unWrap(recipient.private, expectedAuthor: node.public),
        throwsA(isA<Exception>()),
      );
    });
  });
}
