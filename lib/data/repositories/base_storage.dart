import 'package:sembast/sembast.dart';

/// Base repository
/// A base interface for a Sembast-backed storage of items of type [T].
/// Sub-class must implement:
///   • `toDbMap`   → encode  T  → Map
///   • `fromDbMap` → decode  Map → T
abstract class BaseStorage<T> {
  final Database db;
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

  Future<T?> getItem(String id) async {
    final json = await store.record(id).get(db);
    return json == null ? null : fromDbMap(id, json);
  }

  Future<bool> hasItem(String id) => store.record(id).exists(db);

  /// Delete an item by [id].
  Future<void> deleteItem(String id) async {
    await db.transaction((txn) async {
      await store.record(id).delete(txn);
    });
  }

  /// Delete all items in the store.
  Future<void> deleteAll() async {
    await db.transaction((txn) async {
      await store.delete(txn);
    });
  }

  /// Delete by arbitrary Sembast [Filter].
  Future<int> deleteWhere(Filter filter) async {
    return await db.transaction((txn) async {
      return await store.delete(
        txn,
        finder: Finder(filter: filter),
      );
    });
  }

  Future<List<T>> find({
    Filter? filter,
    List<SortOrder>? sort,
    int? limit,
    int? offset,
  }) async {
    final records = await store.find(
      db,
      finder: Finder(
        filter: filter,
        sortOrders: sort,
        limit: limit,
        offset: offset,
      ),
    );
    return records
        .map((rec) => fromDbMap(rec.key, rec.value))
        .toList(growable: false);
  }

  Future<List<T>> getAll() => find();

  Stream<List<T>> watch({
    Filter? filter,
    List<SortOrder>? sort,
  }) {
    final query = store.query(
      finder: Finder(filter: filter, sortOrders: sort),
    );
    return query.onSnapshots(db).map((snaps) =>
        snaps.map((s) => fromDbMap(s.key, s.value)).toList(growable: false));
  }

  /// Watch a single record by its [id] – emits *null* when deleted.
  Stream<T?> watchById(String id) {
    return store
        .record(id)
        .onSnapshot(db)
        .map((snap) => snap == null ? null : fromDbMap(id, snap.value));
  }

  /// Equality filter on a given [field] (`x == value`)
  Filter eq(String field, Object? value) => Filter.equals(field, value);
}
