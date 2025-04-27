import 'package:sembast/sembast.dart';

/// Base repository
///
/// Sub-class must implement:
///   • `toDbMap`   → encode  T  → Map
///   • `fromDbMap` → decode  Map → T
abstract class BaseStorage<T> {
  final Database db;
  final StoreRef<String, Map<String, dynamic>> store;

  BaseStorage(this.db, this.store);

  Map<String, dynamic> toDbMap(T item);
  T fromDbMap(String key, Map<String, dynamic> json);

  Future<void> putItem(String id, T item) =>
      store.record(id).put(db, toDbMap(item));

  Future<T?> getItem(String id) async {
    final json = await store.record(id).get(db);
    return json == null ? null : fromDbMap(id, json);
  }

  Future<bool> hasItem(String id) => store.record(id).exists(db);

  Future<void> deleteItem(String id) => store.record(id).delete(db);

  Future<void> deleteAll() => store.delete(db);

  /// Delete by arbitrary Sembast [Filter].
  Future<int> deleteWhere(Filter filter) =>
      store.delete(db, finder: Finder(filter: filter));

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
    return query
        .onSnapshots(db)
        .map((snaps) => snaps
            .map((s) => fromDbMap(s.key, s.value))
            .toList(growable: false));
  }

  /// Watch a single record by its [id] – emits *null* when deleted.
  Stream<T?> watchById(String id) {
    return store
        .record(id)
        .onSnapshot(db)
        .map((snap) => snap == null ? null : fromDbMap(id, snap.value));
  }

  // ──────────────────────────  Convenience helpers  ────────────────
  /// Equality filter on a given [field] (`x == value`)
  Filter eq(String field, Object? value) => Filter.equals(field, value);

}
