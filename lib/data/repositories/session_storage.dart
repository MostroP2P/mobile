import 'package:sembast/sembast.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/key_manager/key_manager.dart';

class SessionStorage {
  final Database _database;
  final KeyManager _keyManager;
  final _logger = Logger();

  // Store reference for sessions
  final StoreRef<int, Map<String, dynamic>> _store =
      intMapStoreFactory.store('sessions');

  SessionStorage(
    this._database,
    this._keyManager,
  );

  /// Retrieves all sessions from the database (decodes them as well).
  Future<List<Session>> getAllSessions() async {
    final records = await _store.find(_database);
    final sessions = <Session>[];
    for (final record in records) {
      try {
        final session = await _decodeSession(record.value);
        sessions.add(session);
      } catch (e) {
        _logger.e('Error decoding session for key ${record.key}: $e');
        // Optionally handle or remove corrupted records
      }
    }
    return sessions;
  }

  /// Retrieves one session by keyIndex.
  Future<Session?> getSession(int keyIndex) async {
    final record = await _store.record(keyIndex).get(_database);
    if (record == null) {
      return null;
    }
    try {
      return await _decodeSession(record);
    } catch (e) {
      _logger.e('Error decoding session index $keyIndex: $e');
      return null;
    }
  }

  /// Saves (inserts or updates) a session in the database.
  Future<void> putSession(Session session) async {
    final jsonMap = session.toJson();
    // Use the session's keyIndex as the DB key
    await _store.record(session.keyIndex).put(_database, jsonMap);
  }

  /// Deletes a specific session from the database.
  Future<void> deleteSession(int keyIndex) async {
    await _store.record(keyIndex).delete(_database);
  }

  /// Finds and deletes sessions considered expired, returning a list of deleted IDs.
  /// (Keeps domain logic here for simplicity; you could also move it into the Manager.)
  Future<List<int>> deleteExpiredSessions(int sessionExpirationHours, int maxBatchSize) async {
    final now = DateTime.now();
    final records = await _store.find(_database);
    final removedIds = <int>[];

    for (final record in records) {
      if (removedIds.length >= maxBatchSize) break;

      try {
        final sessionMap = record.value;
        final startTimeStr = sessionMap['start_time'] as String?;
        if (startTimeStr != null) {
          final startTime = DateTime.parse(startTimeStr);
          if (now.difference(startTime).inHours >= sessionExpirationHours) {
            await _store.record(record.key).delete(_database);
            removedIds.add(record.key);
          }
        }
      } catch (e) {
        // Possibly remove corrupted record
        _logger.e('Error processing session ${record.key}: $e');
        await _store.record(record.key).delete(_database);
        removedIds.add(record.key);
      }
    }

    return removedIds;
  }

  /// Rebuilds a [Session] object from the DB record by re-deriving keys.
  Future<Session> _decodeSession(Map<String, dynamic> map) async {
    final index = map['key_index'] as int;

    // Re-derive trade key from index
    final tradeKey = await _keyManager.deriveTradeKeyFromIndex(index);
    // Re-get masterKey (potentially from secure storage/caching)
    final masterKey = await _keyManager.getMasterKey();

    map['trade_key'] = tradeKey;
    map['master_key'] = masterKey;

    return Session.fromJson(map);
  }
}
