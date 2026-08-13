import 'dart:typed_data';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/shared/utils/chat_keys.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

void main() {
  group('ChatKeys derivation', () {
    // Official test vector: https://mostro.network/protocol/chat.html#test-vector
    const alicePrivate =
        '548f68890c49fa42f104c60352395e60ff030b0b407e955f1eed1400d6c0347a';
    const bobPrivate =
        'f258e73f07386d37133718b6127f873dd7c391b8f43b331ff8254034a13d2943';
    const expectedAlicePublic =
        '000053c3b4773182e7c4c1b72b272d34be01bf4414a6a25c998977c516a46a01';
    const expectedBobPublic =
        '000009ae5cff9f6ba9b05159ec5ed58c187f5882ea77c81ed5dd19163272a5d7';
    const expectedSharedSecret =
        'def6633a53d07d1e829484c4d4bdbbeed2f4b14c21743e63871c174338e39475';
    const expectedConvPublic =
        'bceb1cd2a8e98ee9729122a1693edcc39c3ace04582ff96a26705c5e4078a6f2';
    const expectedSignPublic =
        '1dba04571059183f76b148119cfa6f8004dad30cb4e810180a6df17386a7f0b4';

    test('reproduces the official protocol test vector', () {
      final alice = NostrKeyPairs(private: alicePrivate);
      final bob = NostrKeyPairs(private: bobPrivate);
      expect(alice.public, equals(expectedAlicePublic));
      expect(bob.public, equals(expectedBobPublic));

      final shared = NostrUtils.computeSharedKey(alicePrivate, bob.public);
      expect(shared.private, equals(expectedSharedSecret));

      final chatKeys = ChatKeys.fromSharedKey(shared);
      expect(chatKeys.conv.public, equals(expectedConvPublic));
      expect(chatKeys.sign.public, equals(expectedSignPublic));
    });

    test('both parties derive the same chat keys', () {
      final alice = NostrUtils.generateKeyPair();
      final bob = NostrUtils.generateKeyPair();

      final aliceChatKeys = ChatKeys.fromSharedKey(
        NostrUtils.computeSharedKey(alice.private, bob.public),
      );
      final bobChatKeys = ChatKeys.fromSharedKey(
        NostrUtils.computeSharedKey(bob.private, alice.public),
      );

      expect(aliceChatKeys.conv.public, equals(bobChatKeys.conv.public));
      expect(aliceChatKeys.sign.public, equals(bobChatKeys.sign.public));
    });

    test('K_conv and K_sign are distinct', () {
      final alice = NostrUtils.generateKeyPair();
      final bob = NostrUtils.generateKeyPair();

      final chatKeys = ChatKeys.fromSharedKey(
        NostrUtils.computeSharedKey(alice.private, bob.public),
      );

      expect(chatKeys.conv.private, isNot(equals(chatKeys.sign.private)));
      expect(chatKeys.conv.public, isNot(equals(chatKeys.sign.public)));
    });

    test('different counterparties produce different chat keys', () {
      final admin = NostrUtils.generateKeyPair();
      final buyer = NostrUtils.generateKeyPair();
      final seller = NostrUtils.generateKeyPair();

      final buyerChatKeys = ChatKeys.fromSharedKey(
        NostrUtils.computeSharedKey(admin.private, buyer.public),
      );
      final sellerChatKeys = ChatKeys.fromSharedKey(
        NostrUtils.computeSharedKey(admin.private, seller.public),
      );

      expect(
        buyerChatKeys.conv.public,
        isNot(equals(sellerChatKeys.conv.public)),
      );
      expect(
        buyerChatKeys.sign.public,
        isNot(equals(sellerChatKeys.sign.public)),
      );
    });

    test('rejects a shared secret that is not 32 bytes', () {
      expect(
        () => ChatKeys.fromSharedSecret(Uint8List(16)),
        throwsArgumentError,
      );
    });
  });
}
