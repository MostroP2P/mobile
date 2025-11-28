import 'dart:convert';
import 'package:dart_nostr/dart_nostr.dart';

/// Utilities for determining message types from NostrEvent content
class MessageTypeUtils {
  /// Helper function to check if a message is an encrypted image
  static bool isEncryptedImageMessage(NostrEvent message) {
    try {
      final content = message.content;
      if (content == null || !content.startsWith('{')) return false;

      final jsonContent = jsonDecode(content) as Map<String, dynamic>;
      return jsonContent['type'] == 'image_encrypted';
    } catch (e) {
      return false;
    }
  }

  /// Helper function to check if a message is an encrypted file
  static bool isEncryptedFileMessage(NostrEvent message) {
    try {
      final content = message.content;
      if (content == null || !content.startsWith('{')) return false;

      final jsonContent = jsonDecode(content) as Map<String, dynamic>;
      return jsonContent['type'] == 'file_encrypted';
    } catch (e) {
      return false;
    }
  }
  
  /// Get the message type enum for more structured handling
  static MessageContentType getMessageType(NostrEvent message) {
    if (isEncryptedImageMessage(message)) return MessageContentType.encryptedImage;
    if (isEncryptedFileMessage(message)) return MessageContentType.encryptedFile;
    return MessageContentType.text;
  }
}

/// Enum representing different types of message content
enum MessageContentType {
  text,
  encryptedImage,
  encryptedFile,
}