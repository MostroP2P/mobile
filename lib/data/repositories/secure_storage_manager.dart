import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/core/utils/nostr_utils.dart';

class SecureStorageManager {
  Timer? _cleanupTimer;
  final int sessionExpirationHours = 48;

  SecureStorageManager() {
    _initializeCleanup();
  }

  Future<Session> newSession() async {
    final keys = NostrUtils.generateKeyPair();
    final session = Session(
      sessionId: keys.public,
      startTime: DateTime.now(),
      keyPair: keys,
    );
    await saveSession(session);
    return session;
  }

  Future<void> saveSession(Session session) async {
    final prefs = await SharedPreferences.getInstance();
    String sessionJson = jsonEncode(session.toJson());
    await prefs.setString(session.sessionId, sessionJson);
  }

  Future<Session?> loadSession(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    String? sessionJson = prefs.getString(sessionId);
    if (sessionJson != null) {
      return Session.fromJson(jsonDecode(sessionJson));
    }
    return null;
  }

  Future<void> deleteSession(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(sessionId);
  }

  Future<void> clearExpiredSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final allKeys = prefs.getKeys();

    for (var key in allKeys) {
      final sessionJson = prefs.getString(key);
      if (sessionJson != null) {
        final session = Session.fromJson(jsonDecode(sessionJson));
        if (now.difference(session.startTime).inHours >= sessionExpirationHours) {
          await prefs.remove(key);
        }
      }
    }
  }

  void _initializeCleanup() {
    clearExpiredSessions();
    _cleanupTimer = Timer.periodic(Duration(minutes: 30), (timer) {
      clearExpiredSessions();
    });
  }

  void dispose() {
    _cleanupTimer?.cancel();
  }
}
