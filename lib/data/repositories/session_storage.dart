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

  /// Record-key prefix for pending range-order child sessions, which have no
  /// orderId yet and are keyed by their trade public key instead.
  static const String pendingChildKeyPrefix = 'pending-child:';

  Future<void> putSession(Session session) async {
    if (session.orderId == null) {
      throw ArgumentError('Cannot store a session with an empty orderId');
    }
    await putItem(session.orderId!, session);
  }

  /// Persists a pending range-order child session (no orderId yet), keyed by
  /// its trade public key. Persisting it matters for two reasons: the session
  /// must survive an app kill between release and the child new-order message,
  /// and the background isolate loads sessions from this store to decrypt
  /// events addressed to the child trade key.
  Future<void> putPendingChildSession(Session session) async {
    if (session.orderId != null) {
      throw ArgumentError(
        'Pending child session must not have an orderId; use putSession',
      );
    }
    if (session.parentOrderId == null) {
      throw ArgumentError('Pending child session requires a parentOrderId');
    }
    await putItem('$pendingChildKeyPrefix${session.tradeKey.public}', session);
  }

  /// Removes the pending child session record for [tradeKeyPublic], if any.
  /// Called once the child order id is known and the session is re-stored
  /// under its orderId, or when an expired pending child is cleaned up.
  Future<void> deletePendingChildSession(String tradeKeyPublic) =>
      deleteItem('$pendingChildKeyPrefix$tradeKeyPublic');

  /// Shortcut to get a single session by its ID.
  Future<Session?> getSession(String sessionId) => getItem(sessionId);

  /// Shortcut to get all sessions (direct pass-through).
  Future<List<Session>> getAllSessions() => getAll();

  /// Shortcut to remove a specific session by its ID.
  Future<void> deleteSession(String sessionId) => deleteItem(sessionId);

  /// Watch a single session by ID with immediate value emission
  Stream<Session?> watchSession(String sessionId) => watchById(sessionId);

  /// Watch all sessions with immediate value emission
  Stream<List<Session>> watchAllSessions() => watch();
}
