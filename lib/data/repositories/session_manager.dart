import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mostro_mobile/data/models/enums/storage_keys.dart';
import 'package:mostro_mobile/features/key_manager/key_manager.dart';
import 'package:mostro_mobile/data/models/session.dart';

class SessionManager {
  final KeyManager _keyManager;
  final FlutterSecureStorage _secureStorage;
  final Map<int, Session> _sessions = {};

  Timer? _cleanupTimer;
  final int sessionExpirationHours = 48;
  static const cleanupIntervalMinutes = 30;
  static const maxBatchSize = 100;

  SessionManager(this._keyManager, this._secureStorage) {
    _initializeCleanup();
  }

  /// Call this after app startup to load sessions from storage
  Future<void> init() async {
    final allEntries = await _secureStorage.readAll();
    for (final entry in allEntries.entries) {
      if (entry.key.startsWith(SecureStorageKeys.sessionKey.value)) {
        try {
          final session = await _decodeSession(entry.value);
          _sessions[session.keyIndex] = session;
        } catch (e) {
          print('Error decoding session for key ${entry.key}: $e');
          // Decide if you want to remove the corrupted entry
        }
      }
    }
  }

  Future<Session> newSession({String? orderId}) async {
    final masterKey = await _keyManager.getMasterKey();
    final keyIndex = await _keyManager.getCurrentKeyIndex();
    final tradeKey = await _keyManager.deriveTradeKey();
    final session = Session(
      startTime: DateTime.now(),
      masterKey: masterKey,
      keyIndex: keyIndex,
      tradeKey: tradeKey,
      fullPrivacy: false,
      orderId: orderId,
    );
    _sessions[keyIndex] = session;
    await saveSession(session);
    return session;
  }

  Future<void> saveSession(Session session) async {
    String sessionJson = jsonEncode(session.toJson());
    await _secureStorage.write(
        key: '${SecureStorageKeys.sessionKey}${session.keyIndex}',
        value: sessionJson);
  }

  Session? getSessionByOrderId(String orderId) {
    try {
      return _sessions.values.firstWhere((s) => s.orderId == orderId);
    } on StateError {
      return null;
    }
  }

  Future<Session?> loadSession(int keyIndex) async {
    if (_sessions.containsKey(keyIndex)) {
      return _sessions[keyIndex];
    }
    final storedJson = await _secureStorage.read(
        key: '${SecureStorageKeys.sessionKey}$keyIndex');
    if (storedJson != null) {
      try {
        final session = await _decodeSession(storedJson);
        _sessions[keyIndex] = session;
        return session;
      } catch (e) {
        print('Error decoding session index $keyIndex: $e');
      }
    }
    return null;
  }

  Future<Session> _decodeSession(String jsonData) async {
    final map = jsonDecode(jsonData) as Map<String, dynamic>;
    final index = map['key_index'] as int;
    final tradeKey = await _keyManager.deriveTradeKeyFromIndex(index);
    final masterKey = await _keyManager.getMasterKey();
    map['trade_key'] = tradeKey;
    map['master_key'] = masterKey;
    return Session.fromJson(map);
  }

  Future<void> deleteSession(int sessionId) async {
    _sessions.remove(sessionId);
    await _secureStorage.delete(
        key: '${SecureStorageKeys.sessionKey}$sessionId');
  }

  Future<void> clearExpiredSessions() async {
    try {
      final now = DateTime.now();
      final allEntries = await _secureStorage.readAll();
      final entries = allEntries.entries
          .where((e) => e.key.startsWith(SecureStorageKeys.sessionKey.value))
          .toList();

      int processedCount = 0;
      for (final entry in entries) {
        if (processedCount >= maxBatchSize) break;
        try {
          final sessionMap = jsonDecode(entry.value) as Map<String, dynamic>;
          final startTime = DateTime.parse(sessionMap['start_time'] as String);
          final index = sessionMap['key_index'] as int;
          if (now.difference(startTime).inHours >= sessionExpirationHours) {
            await _secureStorage.delete(key: entry.key);
            _sessions.remove(index);
            processedCount++;
          }
        } catch (e) {
          print('Error processing session ${entry.key}: $e');
          // Possibly remove corrupted entry
          await _secureStorage.delete(key: entry.key);
          processedCount++;
        }
      }
    } catch (e) {
      print('Error during session cleanup: $e');
    }
  }

  void _initializeCleanup() {
    _cleanupTimer?.cancel();
    clearExpiredSessions();
    _cleanupTimer =
        Timer.periodic(Duration(minutes: cleanupIntervalMinutes), (timer) {
      clearExpiredSessions();
    });
  }

  void dispose() {
    _cleanupTimer?.cancel();
  }

  List<Session> get sessions => _sessions.values.toList();
}
