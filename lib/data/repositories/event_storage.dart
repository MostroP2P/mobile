import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/repositories/base_storage.dart';
import 'package:sembast/sembast.dart';

class EventStorage extends BaseStorage<Map<String, dynamic>> {
  final _logger = Logger();

  EventStorage({
    required Database db,
  }) : super(
          db,
          stringMapStoreFactory.store('events'),
        );

  @override
  Map<String, dynamic> fromDbMap(String key, Map<String, dynamic> event) {
    return event;
  }

  @override
  Map<String, dynamic> toDbMap(Map<String, dynamic> event) {
    return event;
  }

  /// Delete all events except admin events
  /// This preserves admin event IDs to prevent reprocessing historical restore messages
  Future<void> deleteAllExceptAdmin() async {
    final allRecords = await store.find(db);

    int deletedCount = 0;
    int preservedCount = 0;

    await db.transaction((txn) async {
      for (final record in allRecords) {
        final eventType = record.value['type'] as String?;

        if (eventType != 'admin') {
          await store.record(record.key).delete(txn);
          deletedCount++;
        } else {
          preservedCount++;
        }
      }
    });

    _logger.i('deleteAllExceptAdmin: deleted $deletedCount events, preserved $preservedCount admin events');
  }

  /// WARNING: This deletes ALL events including admin events
  ///
  /// DANGEROUS: Deleting admin events will cause restore messages to be reprocessed
  /// on next app restart, potentially creating duplicate restore operations.
  ///
  /// Only use this when:
  /// - Generating a new master key (old admin events can't be decrypted anyway)
  /// - Complete app reset is required
  ///
  /// For restore operations, use deleteAllExceptAdmin() instead.
  @override
  Future<void> deleteAll() async {
    final allRecords = await store.find(db);

    int adminEventsDeleted = 0;
    int totalDeleted = 0;

    await db.transaction((txn) async {
      for (final record in allRecords) {
        final eventType = record.value['type'] as String?;

        if (eventType == 'admin') {
          adminEventsDeleted++;
        }

        await store.record(record.key).delete(txn);
        totalDeleted++;
      }
    });

    if (adminEventsDeleted > 0) {
      _logger.w('WARNING: deleteAll deleted $adminEventsDeleted admin events! '
          'This may cause restore message reprocessing on next startup. '
          'Total events deleted: $totalDeleted');
    } else {
      _logger.i('deleteAll: deleted $totalDeleted events (no admin events present)');
    }
  }
}
