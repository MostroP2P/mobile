import 'package:shared_preferences/shared_preferences.dart';
import 'package:mostro_mobile/features/disputes/notifiers/dispute_chat_notifier.dart';
import 'package:mostro_mobile/services/logger_service.dart';

class DisputeReadStatusService {
  static const String _keyPrefix = 'dispute_last_read_';

  /// Mark a dispute chat as read by storing the current timestamp.
  ///
  /// Read status is bookkeeping: a storage failure is logged and swallowed
  /// rather than propagated, so it can never reach the UI as a dead tap or an
  /// unhandled error.
  static Future<void> markDisputeAsRead(String disputeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_keyPrefix$disputeId';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(key, timestamp);
    } catch (e, stack) {
      logger.w(
        'Failed to mark dispute $disputeId as read',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Get the last read timestamp for a dispute chat.
  ///
  /// Returns null when storage is unavailable, which callers already treat as
  /// "nothing read yet".
  static Future<int?> getLastReadTime(String disputeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_keyPrefix$disputeId';
      return prefs.getInt(key);
    } catch (e, stack) {
      logger.w(
        'Failed to read the last read time for dispute $disputeId',
        error: e,
        stackTrace: stack,
      );
      return null;
    }
  }

  /// Check if there are unread messages in a dispute chat.
  ///
  /// Returns true if any messages (from admin or peer) are newer than the last
  /// read timestamp. Its only storage access goes through [getLastReadTime],
  /// so a storage failure surfaces here as "nothing read yet" — every incoming
  /// message counts as unread — rather than as an error.
  static Future<bool> hasUnreadMessages(
    String disputeId,
    List<DisputeChatMessage> messages, {
    required bool Function(DisputeChatMessage) isFromUser,
  }) async {
    final lastReadTime = await getLastReadTime(disputeId);

    // If no read time is stored, consider all non-user messages as unread
    if (lastReadTime == null) {
      return messages.any((message) => !isFromUser(message));
    }

    // Check if any non-user messages are newer than the last read time
    for (final message in messages) {
      // Skip messages from the current user
      if (isFromUser(message)) continue;

      // Check if message timestamp is newer than last read time
      final messageTime = message.timestamp.millisecondsSinceEpoch;
      if (messageTime > lastReadTime) {
        return true;
      }
    }

    return false;
  }
}
