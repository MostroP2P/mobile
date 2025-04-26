import 'package:mostro_mobile/data/repositories/base_storage.dart';
import 'package:sembast/sembast.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/key_manager/key_manager.dart';
import 'package:sembast/utils/value_utils.dart';

class SessionStorage extends BaseStorage<Session> {
  final KeyManager _keyManager;

  SessionStorage(
    this._keyManager, {
    required Database db,
  }) : super(
          db,
          stringMapStoreFactory.store('sessions'),
        );

  @override
  Map<String, dynamic> toDbMap(Session session) {
    return session.toJson();
  }

  @override
  Session fromDbMap(String key, Map<String, dynamic> jsonMap) {
    return _decodeSession(key, jsonMap);
  }

  /// A specialized decode that re-derives keys or changes the map structure
  Session _decodeSession(String key, Map<String, dynamic> map) {
    final clone = cloneMap(map);

    // Fetch Master Key from KeyManager
    final masterKey = _keyManager.masterKeyPair;

    final keyIndex = map['key_index'];
    final tradeKey = map['trade_key'];

    final tradeKeyPair = _keyManager.deriveTradeKeyPair(keyIndex);
    if (tradeKeyPair.public != tradeKey) {
      throw ArgumentError('Trade key does not match derived key');
    }
    clone['trade_key'] = tradeKeyPair;
    clone['master_key'] = masterKey;

    return Session.fromJson(clone);
  }

  Future<void> putSession(Session session) async {
    if (session.orderId == null) {
      throw ArgumentError('Cannot store a session with an empty orderId');
    }
    await putItem(session.orderId!, session);
  }

  /// Shortcut to get a single session by its ID.
  Future<Session?> getSession(String sessionId) => getItem(sessionId);

  /// Shortcut to get all sessions (direct pass-through).
  Future<List<Session>> getAllSessions() => getAllItems();

  /// Shortcut to remove a specific session by its ID.
  Future<void> deleteSession(String sessionId) => deleteItem(sessionId);

  Future<List<String>> deleteExpiredSessions(
    int sessionExpirationHours,
    int maxBatchSize,
  ) async {
    final now = DateTime.now();
    return await deleteWhere((session) {
      final startTime = session.startTime;
      return now.difference(startTime).inHours >= sessionExpirationHours;
    }, maxBatchSize: maxBatchSize);
  }
  
  /// Watch a session by ID and get a stream of updates
  Stream<Session?> watchSession(String orderId) {
    return store
      .record(orderId)
      .onSnapshot(db)
      .map((snapshot) => snapshot != null 
        ? fromDbMap(snapshot.key, snapshot.value) 
        : null);
  }
  
  /// Watch all sessions and get a stream of updates
  Stream<List<Session>> watchAllSessions({Filter? filter}) {
    final finder = filter != null ? Finder(filter: filter) : null;
    
    return store
      .query(finder: finder)
      .onSnapshots(db)
      .map((snapshots) => snapshots
        .map((snapshot) => fromDbMap(snapshot.key, snapshot.value))
        .toList());
  }
  
  /// Watch active sessions by comparing with current time
  Stream<List<Session>> watchActiveSessions(int sessionExpirationHours) {
    final now = DateTime.now();
    final expirationTime = now.subtract(Duration(hours: sessionExpirationHours));
    
    // Filter for sessions that have startTime newer than expirationTime
    final filter = Filter.greaterThan('start_time', expirationTime.millisecondsSinceEpoch);
    final finder = Finder(filter: filter, sortOrders: [SortOrder('start_time', false)]);
    
    return store
      .query(finder: finder)
      .onSnapshots(db)
      .map((snapshots) => snapshots
        .map((snapshot) => fromDbMap(snapshot.key, snapshot.value))
        .toList());
  }
}
