import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/enums/role.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/repositories/session_storage.dart';
import 'package:mostro_mobile/features/key_manager/key_manager.dart';
import 'package:mostro_mobile/features/settings/settings.dart';

class SessionNotifier extends StateNotifier<List<Session>> {
  // Dependencies
  final Logger _logger = Logger();
  final KeyManager _keyManager;
  final SessionStorage _storage;

  // Current settings
  Settings _settings;

  // In-memory session cache, keyed by `session.keyIndex`.
  final Map<String, Session> _sessions = {};

  // Cleanup / expiration logic
  Timer? _cleanupTimer;
  static const int sessionExpirationHours = 36;
  static const int cleanupIntervalMinutes = 30;
  static const int maxBatchSize = 100;

  /// Public getter to expose sessions (if needed)
  List<Session> get sessions => _sessions.values.toList();

  SessionNotifier(
    this._keyManager,
    this._storage,
    this._settings,
  ) : super([]) {
    //_init();
    //_initializeCleanup();
  }

  /// Initialize by loading all sessions from DB into memory, then updating state.
  Future<void> init() async {
    final allSessions = await _storage.getAllSessions();
    for (final session in allSessions) {
      _sessions[session.orderId!] = session;
    }
    // Update the notifier state with fresh data.
    state = sessions;
  }

  /// Update the application settings if needed.
  void updateSettings(Settings settings) {
    _settings = settings.copyWith();
    // You might want to refresh or do something else if settings impact sessions.
  }

  /// Creates a new session, storing it both in memory and in the database.
  Future<Session> newSession({String? orderId, Role? role}) async {
    final masterKey = _keyManager.masterKeyPair!;
    final keyIndex = await _keyManager.getCurrentKeyIndex();
    final tradeKey = await _keyManager.deriveTradeKey();

    final session = Session(
      startTime: DateTime.now(),
      masterKey: masterKey,
      keyIndex: keyIndex,
      tradeKey: tradeKey,
      fullPrivacy: _settings.fullPrivacyMode,
      orderId: orderId,
      role: role,
    );

    // Cache it in memory

    if (orderId != null) {
      _sessions[orderId] = session;
      // Persist it to DB
      await _storage.putSession(session);
      state = sessions;
    } else {
      state = [...sessions, session];
    }
    return session;
  }

  /// Updates a session in both memory and database.
  Future<void> saveSession(Session session) async {
    _sessions[session.orderId!] = session;
    await _storage.putSession(session);
    state = sessions;
  }

  /// Retrieve the first session whose `orderId` matches [orderId].
  Session? getSessionByOrderId(String orderId) {
    try {
      return _sessions[orderId];
    } on StateError {
      return null;
    }
  }

  /// Retrieve a session by its keyIndex (checks memory first, then DB).
  Future<Session?> loadSession(int keyIndex) async {
    final sessions = await _storage.getAllSessions();
    return sessions.firstWhere((s) => s.keyIndex == keyIndex);
  }

  /// Resets all stored sessions by clearing DB and memory.
  Future<void> reset() async {
    await _storage.deleteAllItems();
    _sessions.clear();
    state = [];
  }

  /// Deletes a session from memory and DB.
  Future<void> deleteSession(String sessionId) async {
    _sessions.remove(sessionId);
    await _storage.deleteSession(sessionId);
    state = sessions;
  }

  /// Removes sessions older than [sessionExpirationHours] from both DB and memory.
  Future<void> clearExpiredSessions() async {
    try {
      final removedIds = await _storage.deleteExpiredSessions(
        sessionExpirationHours,
        maxBatchSize,
      );
      for (final id in removedIds) {
        // If your underlying session keys are strings,
        // you may have to parse them to int or store them as-is.
        _sessions.remove(id);
      }
      state = sessions;
    } catch (e) {
      _logger.e('Error during session cleanup: $e');
    }
  }

  /// Set up an initial cleanup run and a periodic timer.
  void _initializeCleanup() {
    _cleanupTimer?.cancel();
    // Immediately do a cleanup pass
    clearExpiredSessions();
    // Schedule periodic cleanup
    _cleanupTimer = Timer.periodic(
      const Duration(minutes: cleanupIntervalMinutes),
      (_) => clearExpiredSessions(),
    );
  }

  /// Dispose resources (like timers) when no longer needed.
  @override
  void dispose() {
    _cleanupTimer?.cancel();
    super.dispose();
  }
}
