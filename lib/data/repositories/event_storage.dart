import 'package:mostro_mobile/data/repositories/base_storage.dart';
import 'package:sembast/sembast.dart';

class EventStorage extends BaseStorage<Map<String, dynamic>> {
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

  @override
  Future<void> deleteAll() async {
    final allRecords = await store.find(db);

    await db.transaction((txn) async {
      for (final record in allRecords) {
        final eventType = record.value['type'] as String?;

        if (eventType != 'admin') {
          await store.record(record.key).delete(txn);
        }
      }
    });
  }
}
