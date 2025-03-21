import 'package:sembast/sembast.dart';

/// A base interface for a Sembast-backed storage of items of type [T].
abstract class BaseStorage<T> {
  /// Reference to the Sembast database.
  final Database db;

  /// The Sembast store reference (string key, Map&lt;String, dynamic&gt; value).
  final StoreRef<String, Map<String, dynamic>> store;

  BaseStorage(this.db, this.store);

  /// Convert a domain object [T] to JSON-ready Map.
  Map<String, dynamic> toDbMap(T item);

  /// Decode a JSON Map into domain object [T].
  T fromDbMap(String key, Map<String, dynamic> jsonMap);

  /// Insert or update an item in the store. The item is identified by [id].
  Future<void> putItem(String id, T item) async {
    final jsonMap = toDbMap(item);
    await db.transaction((txn) async {
      await store.record(id).put(txn, jsonMap);
    });
  }

  /// Retrieve an item by [id].
  Future<T?> getItem(String id) async {
    final record = await store.record(id).get(db);
    if (record == null) return null;
    return fromDbMap(id, record);
  }

  /// Return all items in the store.
  Future<List<T>> getAllItems() async {
    final records = await store.find(db);
    final result = <T>[];
    for (final record in records) {
      try {
        final item = fromDbMap(record.key, record.value);
        result.add(item);
      } catch (e) {
        // Optionally handle or log parse errors
      }
    }
    return result;
  }

  /// Delete an item by [id].
  Future<void> deleteItem(String id) async {
    await db.transaction((txn) async {
      await store.record(id).delete(txn);
    });
  }

  /// Delete all items in the store.
  Future<void> deleteAllItems() async {
    await db.transaction((txn) async {
      await store.delete(txn);
    });
  }

  /// Delete items that match a predicate [filter].
  /// Return the list of deleted IDs.
  Future<List<String>> deleteWhere(bool Function(T) filter,
      {int? maxBatchSize}) async {
    final toDelete = <String>[];
    final records = await store.find(db);

    for (final record in records) {
      if (maxBatchSize != null && toDelete.length >= maxBatchSize) {
        break;
      }
      try {
        final item = fromDbMap(record.key, record.value);
        if (filter(item)) {
          toDelete.add(record.key);
        }
      } catch (_) {
        // Could not parse => also consider removing or ignoring
        toDelete.add(record.key);
      }
    }

    // Remove the matched records in a transaction
    await db.transaction((txn) async {
      for (final key in toDelete) {
        await store.record(key).delete(txn);
      }
    });

    return toDelete;
  }

  /// If needed, close or clean up resources here.
  void dispose() {}
}
