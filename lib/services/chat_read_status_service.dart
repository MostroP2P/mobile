import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_nostr/dart_nostr.dart';

class ChatReadStatusService {
  static const String _keyPrefix = 'chat_last_read_';

  /// Mark a chat as read by storing the current timestamp
  static Future<void> markChatAsRead(String orderId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$orderId';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(key, timestamp);
  }

  /// Get the last read timestamp for a chat
  static Future<int?> getLastReadTime(String orderId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$orderId';
    return prefs.getInt(key);
  }

  /// Check if there are unread messages in a chat
  /// Returns true if any peer messages are newer than the last read timestamp
  static Future<bool> hasUnreadMessages(String orderId, List<NostrEvent> messages, String currentUserPubkey) async {
    final lastReadTime = await getLastReadTime(orderId);
    
    // If no read time is stored, consider all peer messages as unread
    if (lastReadTime == null) {
      return messages.any((message) => message.pubkey != currentUserPubkey);
    }

    // Check if any peer messages are newer than the last read time
    for (final message in messages) {
      // Skip messages from the current user
      if (message.pubkey == currentUserPubkey) continue;
      
      // Check if message timestamp is newer than last read time
      if (message.createdAt != null) {
        final messageTime = message.createdAt!.millisecondsSinceEpoch;
        if (messageTime > lastReadTime) {
          return true;
        }
      }
    }
    
    return false;
  }
}
