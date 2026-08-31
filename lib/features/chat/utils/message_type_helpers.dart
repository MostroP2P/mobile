import 'dart:convert';
import 'package:dart_nostr/dart_nostr.dart';

/// Utilities for determining message types from NostrEvent content.
///
/// Message content is immutable per event id, so the classification is
/// decoded once and memoized: the bubble used to run up to two jsonDecode
/// calls per build per message.
class MessageTypeUtils {
  static const int _cacheLimit = 2000;
  static final Map<String, (String?, MessageContentType)> _cache = {};

  /// Test hook: the memoized classification for an event id, if any.
  static MessageContentType? cachedTypeFor(String eventId) =>
      _cache[eventId]?.$2;

  static bool isEncryptedImageMessage(NostrEvent message) =>
      getMessageType(message) == MessageContentType.encryptedImage;

  static bool isEncryptedFileMessage(NostrEvent message) =>
      getMessageType(message) == MessageContentType.encryptedFile;

  /// Get the message type enum for more structured handling
  static MessageContentType getMessageType(NostrEvent message) {
    final id = message.id;
    if (id != null) {
      final cached = _cache[id];
      // Validated by content identity: a rebuild passes the same event
      // instance and hits; a different content under a reused id (tests,
      // hypothetical replacements) re-classifies.
      if (cached != null && identical(cached.$1, message.content)) {
        return cached.$2;
      }
    }
    final type = _classify(message);
    if (id != null) {
      if (_cache.length >= _cacheLimit) {
        _cache.clear();
      }
      _cache[id] = (message.content, type);
    }
    return type;
  }

  static MessageContentType _classify(NostrEvent message) {
    try {
      final content = message.content;
      if (content == null || !content.trimLeft().startsWith('{')) {
        return MessageContentType.text;
      }
      final jsonContent = jsonDecode(content) as Map<String, dynamic>;
      switch (jsonContent['type']) {
        case 'image_encrypted':
          return MessageContentType.encryptedImage;
        case 'file_encrypted':
          return MessageContentType.encryptedFile;
        default:
          return MessageContentType.text;
      }
    } catch (e) {
      return MessageContentType.text;
    }
  }
}

/// Enum representing different types of message content
enum MessageContentType {
  text,
  encryptedImage,
  encryptedFile,
}
