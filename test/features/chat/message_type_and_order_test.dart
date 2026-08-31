import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/chat_room.dart';
import 'package:mostro_mobile/features/chat/utils/message_type_helpers.dart';

/// Chat render costs: the bubble ran up to two `jsonDecode`s of the message
/// content per build to classify it, and the message list re-sorted the room
/// on every build even though `ChatRoom`'s constructor already sorts. The
/// classification is now decoded once and memoized by event id, and the
/// ascending constructor order is the single canonical order.
void main() {
  NostrEvent event(String id, {String? content, required int createdAt}) =>
      NostrEvent(
        id: id,
        kind: 14,
        content: content ?? 'hola',
        sig: '',
        pubkey: 'peer',
        createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
        tags: const [],
      );

  group('MessageTypeUtils', () {
    test('classifies text, encrypted image and encrypted file', () {
      expect(MessageTypeUtils.getMessageType(event('t', createdAt: 1)),
          MessageContentType.text);
      expect(
        MessageTypeUtils.getMessageType(event('i',
            content: '{"type":"image_encrypted","url":"x"}', createdAt: 1)),
        MessageContentType.encryptedImage,
      );
      expect(
        MessageTypeUtils.getMessageType(event('f',
            content: '{"type":"file_encrypted","url":"x"}', createdAt: 1)),
        MessageContentType.encryptedFile,
      );
      expect(
        MessageTypeUtils.getMessageType(event('wi',
            content: '  \n{"type":"image_encrypted","url":"x"}',
            createdAt: 1)),
        MessageContentType.encryptedImage,
      );
      expect(
        MessageTypeUtils.getMessageType(event('wf',
            content: '\t{"type":"file_encrypted","url":"x"}', createdAt: 1)),
        MessageContentType.encryptedFile,
      );
      expect(
        MessageTypeUtils.getMessageType(
            event('j', content: '{"type":"other"}', createdAt: 1)),
        MessageContentType.text,
      );
      expect(
        MessageTypeUtils.getMessageType(
            event('b', content: '{broken json', createdAt: 1)),
        MessageContentType.text,
      );
    });

    test('boolean helpers agree with the classification', () {
      final img = event('i2',
          content: '{"type":"image_encrypted","url":"x"}', createdAt: 1);
      expect(MessageTypeUtils.isEncryptedImageMessage(img), isTrue);
      expect(MessageTypeUtils.isEncryptedFileMessage(img), isFalse);
    });

    test('the classification is memoized per event id', () {
      final e = event('memo',
          content: '{"type":"image_encrypted","url":"x"}', createdAt: 1);
      MessageTypeUtils.getMessageType(e);

      expect(MessageTypeUtils.cachedTypeFor('memo'),
          MessageContentType.encryptedImage,
          reason: 'a bubble rebuild must not re-decode the JSON content');
    });
  });

  group('ChatRoom canonical order', () {
    test('constructor sorts ascending regardless of input order', () {
      final room = ChatRoom(orderId: 'o1', messages: [
        event('late', createdAt: 300),
        event('early', createdAt: 100),
        event('mid', createdAt: 200),
      ]);

      expect(room.messages.map((m) => m.id), ['early', 'mid', 'late']);
    });

    test('copy() keeps the ascending order after appending', () {
      final room = ChatRoom(orderId: 'o1', messages: [
        event('early', createdAt: 100),
      ]);

      final updated =
          room.copy(messages: [...room.messages, event('late', createdAt: 50)]);

      expect(updated.messages.map((m) => m.id), ['late', 'early']);
    });
  });
}
