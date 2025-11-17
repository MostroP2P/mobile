import 'package:mostro_mobile/data/repositories/base_storage.dart';
import 'package:sembast/sembast.dart';

/// Storage for notification deduplication state
///
/// This store tracks which events have been processed for notifications
/// to prevent duplicate notifications. It is separate from the events
/// store to maintain clear separation of concerns.
///
/// Schema:
/// - key: event ID (String)
/// - value: Map with:
///   - processed_at: timestamp in milliseconds (int)
///   - notification_shown: whether notification was displayed (bool)
class NotificationStateStorage extends BaseStorage<Map<String, dynamic>> {
  NotificationStateStorage({
    required Database db,
  }) : super(
          db,
          stringMapStoreFactory.store('notification_state'),
        );

  @override
  Map<String, dynamic> fromDbMap(String key, Map<String, dynamic> state) {
    return state;
  }

  @override
  Map<String, dynamic> toDbMap(Map<String, dynamic> state) {
    return state;
  }

  /// Mark an event as processed for notifications
  Future<void> markAsProcessed(String eventId) async {
    await putItem(eventId, {
      'processed_at': DateTime.now().millisecondsSinceEpoch,
      'notification_shown': true,
    });
  }

  /// Check if an event has already been processed
  Future<bool> isProcessed(String eventId) async {
    return await hasItem(eventId);
  }
}
