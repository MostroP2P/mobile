import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mostro_mobile/constants/storage_keys.dart';
import 'package:mostro_mobile/services/key_manager.dart';
import 'package:mostro_mobile/data/models/session.dart';

class SessionManager {
  final KeyManager _keyManager;
  final FlutterSecureStorage _flutterSecureStorage;
  final Map<int, Session> _sessions = {};

  Timer? _cleanupTimer;
  final int sessionExpirationHours = 48;
  static const cleanupIntervalMinutes = 30;
  static const maxBatchSize = 100;

  SessionManager(this._keyManager, this._flutterSecureStorage) {
    _initializeCleanup();
  }

  Future<void> init() async {
    final allKeys = await _flutterSecureStorage.readAll();

    for (var e in allKeys.entries) {
      if (e.key.startsWith(SecureStorageKeys.sessionKey.value)) {
        final session = Session.fromJson(jsonDecode(e.value));
        _sessions[session.keyIndex] = session;
      }
    }
  }

  Future<Session> newSession({String? orderId}) async {
    final keys = await _keyManager.getMasterKey();
    final keyIndex = await _keyManager.getCurrentKeyIndex();
    final tradeKey = await _keyManager.deriveTradeKey();
    final session = Session(
      startTime: DateTime.now(),
      masterKey: keys!,
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
    await _flutterSecureStorage.write(
        key: '${SecureStorageKeys.sessionKey}${session.keyIndex}',
        value: sessionJson);
  }

  Future<Session?> getSession(int sessionId) async {
    if (_sessions.containsKey(sessionId)) {
      return _sessions[sessionId];
    }
    return await loadSession(sessionId);
  }

  Session? getSessionByOrderId(String orderId) {
    try {
      return _sessions.values.firstWhere((s) => s.orderId == orderId);
    } on StateError {
      return null;
    }
  }

  Future<Session?> loadSession(int sessionId) async {
    String? sessionJson = await _flutterSecureStorage.read(
        key: '${SecureStorageKeys.sessionKey}$sessionId');
    if (sessionJson != null) {
      return Session.fromJson(jsonDecode(sessionJson));
    }
    return null;
  }

  Future<void> deleteSession(int sessionId) async {
    _sessions.remove(sessionId);
    await _flutterSecureStorage.delete(
        key: '${SecureStorageKeys.sessionKey}$sessionId');
  }

  Future<void> clearExpiredSessions() async {
    try {
      final now = DateTime.now();
      final allKeys = await _flutterSecureStorage.readAll();
      final entries = allKeys.entries
          .where((e) => e.key.startsWith(SecureStorageKeys.sessionKey.value))
          .toList();

      int processedCount = 0;
      for (final entry in entries) {
        if (processedCount >= maxBatchSize) break;
        final key = entry.key;
        final value = entry.value;
        try {
          final session = Session.fromJson(jsonDecode(value));
          if (now.difference(session.startTime).inHours >=
              sessionExpirationHours) {
            await _flutterSecureStorage.delete(key: key);
            _sessions.remove(session.keyIndex);
            processedCount++;
          }
        } catch (e) {
          print('Error processing session $key: $e');
          await _flutterSecureStorage.delete(key: key);
          _sessions.removeWhere((_, s) => 'session_${s.keyIndex}' == key);
          processedCount++;
        }
      }
    } catch (e) {
      print('Error during session cleanup: $e');
    }
  }

  void _initializeCleanup() {
    clearExpiredSessions();
    _cleanupTimer =
        Timer.periodic(Duration(minutes: cleanupIntervalMinutes), (timer) {
      clearExpiredSessions();
    });
  }

  void dispose() {
    _cleanupTimer?.cancel();
  }
}
