import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/models/nostr_filter.dart';
import 'package:mostro_mobile/shared/utils/chat_keys.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

void main() {
  // Keys from the official chat test vector plus a stranger key
  const alicePrivate =
      '548f68890c49fa42f104c60352395e60ff030b0b407e955f1eed1400d6c0347a';
  const bobPrivate =
      'f258e73f07386d37133718b6127f873dd7c391b8f43b331ff8254034a13d2943';

  final alice = NostrKeyPairs(private: alicePrivate);
  final bob = NostrKeyPairs(private: bobPrivate);
  final stranger = NostrUtils.generateKeyPair();

  final chatKeys = ChatKeys.fromSharedKey(
    NostrUtils.computeSharedKey(alicePrivate, bob.public),
  );
  final allowedSigners = [alice.public, bob.public];

  NostrEvent buildInner(
    NostrKeyPairs sender,
    String text, {
    DateTime? createdAt,
    int kind = 1,
  }) {
    return NostrEvent.fromPartialData(
      keyPairs: sender,
      content: text,
      kind: kind,
      createdAt: createdAt,
    );
  }

  group('createChatRumor', () {
    test('builds a signed kind 1 event with a single u nonce tag', () {
      final rumor = NostrEventExtensions.createChatRumor(
        senderKeys: alice,
        content: 'hello with nonce',
      );

      expect(rumor.kind, equals(1));
      expect(rumor.pubkey, equals(alice.public));
      expect(rumor.id, isNotNull);
      expect(rumor.sig, isNotNull);

      final uTags = rumor.tags!.where((t) => t[0] == 'u').toList();
      expect(rumor.tags!.length, equals(1));
      expect(uTags.length, equals(1));
      expect(uTags[0][1], matches(RegExp(r'^[0-9a-f]{16}$')));
    });

    test('identical content at the same timestamp yields distinct ids', () {
      final createdAt = DateTime.now();
      final first = NostrEventExtensions.createChatRumor(
        senderKeys: alice,
        content: 'ok',
        createdAt: createdAt,
      );
      final second = NostrEventExtensions.createChatRumor(
        senderKeys: alice,
        content: 'ok',
        createdAt: createdAt,
      );

      expect(first.id, isNot(equals(second.id)));
    });
  });

  group('chatWrap', () {
    test('produces a kind 14 envelope with the expected shape', () async {
      final inner = buildInner(alice, 'hello from the test');
      final wrapped = await inner.chatWrap(chatKeys);

      expect(wrapped.kind, equals(14));
      expect(wrapped.pubkey, equals(chatKeys.sign.public));

      final pTags = wrapped.tags!.where((t) => t[0] == 'p').toList();
      expect(pTags.length, equals(1));
      expect(pTags[0][1], equals(chatKeys.conv.public));

      // Inner and outer must share the same timestamp (replay defense)
      expect(
        wrapped.createdAt!.millisecondsSinceEpoch ~/ 1000,
        equals(inner.createdAt!.millisecondsSinceEpoch ~/ 1000),
      );
    });

    test('rejects a non kind 1 inner event', () async {
      final inner = buildInner(alice, 'wrong kind', kind: 5);
      expect(() => inner.chatWrap(chatKeys), throwsArgumentError);
    });
  });

  group('chatUnwrap round-trip', () {
    test('preserves content, sender and inner event id', () async {
      final inner = buildInner(alice, 'hello admin, I need help');
      final wrapped = await inner.chatWrap(chatKeys);

      final unwrapped = await wrapped.chatUnwrap(chatKeys, allowedSigners);

      expect(unwrapped.content, equals('hello admin, I need help'));
      expect(unwrapped.pubkey, equals(alice.public));
      expect(unwrapped.kind, equals(1));
      expect(unwrapped.id, equals(inner.id));
    });

    test('accepts a rumor carrying the u nonce tag', () async {
      final rumor = NostrEventExtensions.createChatRumor(
        senderKeys: alice,
        content: 'nonce round-trip',
      );
      final wrapped = await rumor.chatWrap(chatKeys);

      final unwrapped = await wrapped.chatUnwrap(chatKeys, allowedSigners);

      expect(unwrapped.content, equals('nonce round-trip'));
      expect(unwrapped.id, equals(rumor.id));
      expect(unwrapped.tags!.where((t) => t[0] == 'u').length, equals(1));
    });

    test('works in both directions with the same derived keys', () async {
      final bobChatKeys = ChatKeys.fromSharedKey(
        NostrUtils.computeSharedKey(bobPrivate, alice.public),
      );
      final inner = buildInner(bob, 'reply from the admin');
      final wrapped = await inner.chatWrap(bobChatKeys);

      final unwrapped = await wrapped.chatUnwrap(chatKeys, allowedSigners);

      expect(unwrapped.content, equals('reply from the admin'));
      expect(unwrapped.pubkey, equals(bob.public));
    });
  });

  group('chatUnwrap rejections', () {
    test('rejects an outer event not authored by K_sign', () async {
      final inner = buildInner(alice, 'forged author');
      final wrapped = await inner.chatWrap(chatKeys);

      final forged = NostrEvent.fromPartialData(
        kind: 14,
        content: wrapped.content!,
        keyPairs: stranger,
        tags: wrapped.tags,
        createdAt: wrapped.createdAt,
      );

      await expectLater(
        forged.chatUnwrap(chatKeys, allowedSigners),
        throwsA(isA<Exception>()),
      );
    });

    test('rejects a wrong outer kind', () async {
      final inner = buildInner(alice, 'wrong outer kind');
      final wrapped = await inner.chatWrap(chatKeys);

      final wrongKind = NostrEvent.fromPartialData(
        kind: 1059,
        content: wrapped.content!,
        keyPairs: chatKeys.sign,
        tags: wrapped.tags,
        createdAt: wrapped.createdAt,
      );

      await expectLater(
        wrongKind.chatUnwrap(chatKeys, allowedSigners),
        throwsA(isA<Exception>()),
      );
    });

    test('rejects an outer event with extra p tags', () async {
      final inner = buildInner(alice, 'extra p tag');
      final wrapped = await inner.chatWrap(chatKeys);

      final extraTag = NostrEvent.fromPartialData(
        kind: 14,
        content: wrapped.content!,
        keyPairs: chatKeys.sign,
        tags: [
          ["p", chatKeys.conv.public],
          ["p", stranger.public],
        ],
        createdAt: wrapped.createdAt,
      );

      await expectLater(
        extraTag.chatUnwrap(chatKeys, allowedSigners),
        throwsA(isA<Exception>()),
      );
    });

    test('rejects an outer event dated too far in the future', () async {
      final inner = buildInner(alice, 'from the future');
      final wrapped = await inner.chatWrap(chatKeys);

      await expectLater(
        wrapped.chatUnwrap(
          chatKeys,
          allowedSigners,
          now: wrapped.createdAt!.subtract(const Duration(seconds: 120)),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('rejects an oversized payload before decrypting', () async {
      final oversized = NostrEvent.fromPartialData(
        kind: 14,
        content: 'x' * (NostrEventExtensions.chatMaxContentBytes + 1),
        keyPairs: chatKeys.sign,
        tags: [
          ["p", chatKeys.conv.public],
        ],
      );

      await expectLater(
        oversized.chatUnwrap(chatKeys, allowedSigners),
        throwsA(
          predicate((e) => e.toString().contains('exceeds the accepted size')),
        ),
      );
    });

    test('rejects a tampered outer event (id no longer matches)', () async {
      final inner = buildInner(alice, 'tamper the outer');
      final wrapped = await inner.chatWrap(chatKeys);

      final reEncrypted = await NostrUtils.encryptNIP44(
        jsonEncode(buildInner(alice, 'swapped payload').toMap()),
        chatKeys.conv.private,
        chatKeys.conv.public,
      );
      final tampered = NostrEvent(
        id: wrapped.id,
        kind: wrapped.kind,
        content: reEncrypted,
        sig: wrapped.sig,
        pubkey: wrapped.pubkey,
        createdAt: wrapped.createdAt,
        tags: wrapped.tags,
      );

      await expectLater(
        tampered.chatUnwrap(chatKeys, allowedSigners),
        throwsA(predicate((e) => e.toString().contains('does not match'))),
      );
    });

    test('rejects a tampered inner event (id no longer matches)', () async {
      final inner = buildInner(alice, 'original text');
      final tamperedInner = NostrEvent(
        id: inner.id,
        kind: inner.kind,
        content: 'tampered text',
        sig: inner.sig,
        pubkey: inner.pubkey,
        createdAt: inner.createdAt,
        tags: inner.tags,
      );

      final encrypted = await NostrUtils.encryptNIP44(
        jsonEncode(tamperedInner.toMap()),
        chatKeys.conv.private,
        chatKeys.conv.public,
      );
      final wrapped = NostrEvent.fromPartialData(
        kind: 14,
        content: encrypted,
        keyPairs: chatKeys.sign,
        tags: [
          ["p", chatKeys.conv.public],
        ],
        createdAt: inner.createdAt,
      );

      await expectLater(
        wrapped.chatUnwrap(chatKeys, allowedSigners),
        throwsA(predicate((e) => e.toString().contains('does not match'))),
      );
    });

    test('rejects an inner payload missing required fields as Exception',
        () async {
      final encrypted = await NostrUtils.encryptNIP44(
        '{"kind": 1, "content": "no id, sig, pubkey or tags"}',
        chatKeys.conv.private,
        chatKeys.conv.public,
      );
      final wrapped = NostrEvent.fromPartialData(
        kind: 14,
        content: encrypted,
        keyPairs: chatKeys.sign,
        tags: [
          ["p", chatKeys.conv.public],
        ],
      );

      await expectLater(
        wrapped.chatUnwrap(chatKeys, allowedSigners),
        throwsA(
          predicate((e) =>
              e is Exception &&
              e.toString().contains('Malformed inner chat event')),
        ),
      );
    });

    test('rejects an inner event signed by a non-party key', () async {
      final inner = buildInner(stranger, 'not a party');
      final wrapped = await inner.chatWrap(chatKeys);

      await expectLater(
        wrapped.chatUnwrap(chatKeys, allowedSigners),
        throwsA(predicate((e) => e.toString().contains('not a party'))),
      );
    });

    test('rejects a non kind 1 inner event', () async {
      final inner = buildInner(alice, 'wrong inner kind', kind: 5);
      final encrypted = await NostrUtils.encryptNIP44(
        jsonEncode(inner.toMap()),
        chatKeys.conv.private,
        chatKeys.conv.public,
      );
      final wrapped = NostrEvent.fromPartialData(
        kind: 14,
        content: encrypted,
        keyPairs: chatKeys.sign,
        tags: [
          ["p", chatKeys.conv.public],
        ],
        createdAt: inner.createdAt,
      );

      await expectLater(
        wrapped.chatUnwrap(chatKeys, allowedSigners),
        throwsA(predicate((e) => e.toString().contains('kind 1'))),
      );
    });

    test('rejects a stale re-wrap (timestamps disagree)', () async {
      final staleInner = buildInner(
        alice,
        'stale message',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      final encrypted = await NostrUtils.encryptNIP44(
        jsonEncode(staleInner.toMap()),
        chatKeys.conv.private,
        chatKeys.conv.public,
      );
      final reWrapped = NostrEvent.fromPartialData(
        kind: 14,
        content: encrypted,
        keyPairs: chatKeys.sign,
        tags: [
          ["p", chatKeys.conv.public],
        ],
      );

      await expectLater(
        reWrapped.chatUnwrap(chatKeys, allowedSigners),
        throwsA(
          predicate((e) => e.toString().contains('timestamps disagree')),
        ),
      );
    });
  });

  group('chatSubscriptionFilter', () {
    final since = DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000);

    test('matches by author and bounds the backlog', () {
      final filter = NostrEventExtensions.chatSubscriptionFilter(
        signPubkeys: [chatKeys.sign.public],
        since: since,
      );

      expect(filter.kinds, [14]);
      expect(filter.authors, [chatKeys.sign.public]);
      expect(filter.since, since);
      expect(filter.limit, NostrEventExtensions.chatDefaultLimit);
      // Filtering by #p would let any third party flood the subscription
      expect(filter.p, isNull);
    });

    test('survives the background persist/restore round-trip', () {
      final filter = NostrEventExtensions.chatSubscriptionFilter(
        signPubkeys: [chatKeys.sign.public],
        since: since,
      );

      final restored = NostrFilterX.fromJsonSafe(
        jsonDecode(jsonEncode(filter.toMap())) as Map<String, dynamic>,
      );

      expect(restored.kinds, filter.kinds);
      expect(restored.authors, filter.authors);
      expect(restored.since, filter.since);
      expect(restored.limit, filter.limit);
    });
  });
}
