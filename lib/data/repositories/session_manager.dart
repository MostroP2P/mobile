import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
        key: session.keyIndex.toString(), value: sessionJson);
  }

  Future<Session?> getSession(int sessionId) async {
    if (_sessions.containsKey(sessionId)) {
      return _sessions[sessionId];
    }
    return await loadSession(sessionId);
  }

  Session getSessionByOrderId(String orderId) {
    return _sessions.values.firstWhere((s) => s.orderId == orderId);
  }

  Future<Session?> loadSession(int sessionId) async {
    String? sessionJson =
        await _flutterSecureStorage.read(key: sessionId.toString());
    if (sessionJson != null) {
      return Session.fromJson(jsonDecode(sessionJson));
    }
    return null;
  }

  Future<void> deleteSession(int sessionId) async {
    _sessions.remove(sessionId);
    await _flutterSecureStorage.delete(key: sessionId.toString());
  }

  Future<void> clearExpiredSessions() async {
    try {
      final now = DateTime.now();
      final allKeys = await _flutterSecureStorage.readAll();
      int processedCount = 0;

      allKeys.forEach((key, value) async {
        if (processedCount >= maxBatchSize) {
          // Schedule remaining cleanup for next run
          return;
        }
        final sessionJson = value;
        try {
          final session = Session.fromJson(jsonDecode(sessionJson));
          if (now.difference(session.startTime).inHours >=
              sessionExpirationHours) {
            await _flutterSecureStorage.delete(key: key);
            processedCount++;
          }
        } catch (e) {
          print('Error processing session $key: $e');
          await _flutterSecureStorage.delete(key: key);
          processedCount++;
        }
      });
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
