import 'package:shared_preferences/shared_preferences.dart';
import 'package:mostro_mobile/data/models/dispute_chat.dart';

class DisputeReadStatusService {
  static const String _keyPrefix = 'dispute_last_read_';

  /// Mark a dispute chat as read by storing the current timestamp
  static Future<void> markDisputeAsRead(String disputeId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$disputeId';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(key, timestamp);
  }

  /// Get the last read timestamp for a dispute chat
  static Future<int?> getLastReadTime(String disputeId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$disputeId';
    return prefs.getInt(key);
  }

  /// Check if there are unread messages in a dispute chat
  /// Returns true if any messages (from admin or peer) are newer than the last read timestamp
  static Future<bool> hasUnreadMessages(String disputeId, List<DisputeChat> messages) async {
    final lastReadTime = await getLastReadTime(disputeId);
    
    // If no read time is stored, consider all non-user messages as unread
    if (lastReadTime == null) {
      return messages.any((message) => !message.isFromUser);
    }

    // Check if any non-user messages are newer than the last read time
    for (final message in messages) {
      // Skip messages from the current user
      if (message.isFromUser) continue;
      
      // Check if message timestamp is newer than last read time
      final messageTime = message.timestamp.millisecondsSinceEpoch;
      if (messageTime > lastReadTime) {
        return true;
      }
    }
    
    return false;
  }
}
