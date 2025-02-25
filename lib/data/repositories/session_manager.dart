import 'dart:async';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/repositories/session_storage.dart';
import 'package:mostro_mobile/features/key_manager/key_manager.dart';
import 'package:mostro_mobile/features/settings/settings.dart';

class SessionManager {
  final Logger _logger = Logger();

  final KeyManager _keyManager;
  final SessionStorage _sessionStorage;
  bool fullPrivacyMode = true;

  // In-memory session cache
  final Map<int, Session> _sessions = {};

  Timer? _cleanupTimer;
  final int sessionExpirationHours = 48;
  static const cleanupIntervalMinutes = 30;
  static const maxBatchSize = 100;

  /// Returns all in-memory sessions.
  List<Session> get sessions => _sessions.values.toList();

  SessionManager(
    this._keyManager,
    this._sessionStorage,
  ) {
    _initializeCleanup();
  }

  /// Load all sessions at startup and populate the in-memory map.
  Future<void> init() async {
    final allSessions = await _sessionStorage.getAllSessions();
    for (final session in allSessions) {
      _sessions[session.keyIndex] = session;
    }
  }

  void updateSettings(Settings settings) {
    fullPrivacyMode = settings.fullPrivacyMode;
  }

  /// Creates a new session, storing it both in memory and in the database.
  Future<Session> newSession({String? orderId}) async {
    final masterKey = await _keyManager.getMasterKey();
    final keyIndex = await _keyManager.getCurrentKeyIndex();
    final tradeKey = await _keyManager.deriveTradeKey();

    final session = Session(
      startTime: DateTime.now(),
      masterKey: masterKey,
      keyIndex: keyIndex,
      tradeKey: tradeKey,
      fullPrivacy: fullPrivacyMode,
      orderId: orderId,
    );

    // Cache it in memory
    _sessions[keyIndex] = session;
    // Persist it in the database
    await _sessionStorage.putSession(session);

    return session;
  }

  /// Update a session in both memory and the database.
  Future<void> saveSession(Session session) async {
    _sessions[session.keyIndex] = session;
    await _sessionStorage.putSession(session);
  }

  /// Retrieve the first session that matches a given orderId (from the in-memory map).
  Session? getSessionByOrderId(String orderId) {
    try {
      return _sessions.values.firstWhere((s) => s.orderId == orderId);
    } on StateError {
      return null;
    }
  }

  /// Retrieve a session by its keyIndex (checks memory first, then DB).
  Future<Session?> loadSession(int keyIndex) async {
    if (_sessions.containsKey(keyIndex)) {
      return _sessions[keyIndex];
    }
    final session = await _sessionStorage.getSession(keyIndex);
    if (session != null) {
      _sessions[keyIndex] = session;
    }
    return session;
  }

  /// Removes a session from memory and the database.
  Future<void> deleteSession(int sessionId) async {
    _sessions.remove(sessionId);
    await _sessionStorage.deleteSession(sessionId);
  }

  /// Periodically clear out expired sessions.
  Future<void> clearExpiredSessions() async {
    try {
      final removedIds = await _sessionStorage.deleteExpiredSessions(
        sessionExpirationHours,
        maxBatchSize,
      );
      // Remove them from the in-memory map
      for (final id in removedIds) {
        _sessions.remove(id);
      }
    } catch (e) {
      _logger.e('Error during session cleanup: $e');
    }
  }

  void _initializeCleanup() {
    _cleanupTimer?.cancel();
    // Perform an initial cleanup
    clearExpiredSessions();
    // Schedule periodic cleanup
    _cleanupTimer = Timer.periodic(
      const Duration(minutes: cleanupIntervalMinutes),
      (_) => clearExpiredSessions(),
    );
  }

  /// Dispose resources (e.g., timers) when no longer needed.
  void dispose() {
    _cleanupTimer?.cancel();
  }
}
