import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/data/models/enums/role.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/repositories/session_storage.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:mostro_mobile/data/models/peer.dart';

class SessionNotifier extends StateNotifier<List<Session>> {
  final Ref ref;
  final SessionStorage _storage;
  Settings _settings;
  final Map<String, Session> _sessions = {};
  final Map<int, Session> _requestIdToSession = {};

  Timer? _cleanupTimer;
  final Logger _logger = Logger();

  List<Session> get sessions => _sessions.values.toList();

  SessionNotifier(
    this.ref,
    this._storage,
    this._settings,
  ) : super([]);

  Future<void> init() async {
    final allSessions = await _storage.getAllSessions();
    final cutoff = DateTime.now()
        .subtract(const Duration(hours: Config.sessionExpirationHours));
    for (final session in allSessions) {
      if (session.startTime.isAfter(cutoff)) {
        _sessions[session.orderId!] = session;
      } else {
        await _storage.deleteSession(session.orderId!);
        _sessions.remove(session.orderId!);
      }
    }
    state = sessions;
    _scheduleCleanup();
  }

  void _scheduleCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(
      const Duration(minutes: Config.cleanupIntervalMinutes),
      (timer) => _cleanup(),
    );
  }

  void _cleanup() async {
    final cutoff = DateTime.now()
        .subtract(const Duration(hours: Config.sessionExpirationHours));
    final expiredSessions = await _storage.getAllSessions();
    for (final session in expiredSessions) {
      if (session.startTime.isBefore(cutoff)) {
        await _storage.deleteSession(session.orderId!);
        _sessions.remove(session.orderId!);
      }
    }
    state = sessions;
  }

  void updateSettings(Settings settings) {
    _settings = settings.copyWith();
  }

  Future<Session> newSession(
      {String? orderId, int? requestId, Role? role}) async {
    if (state.any((s) => s.orderId == orderId)) {
      return state.firstWhere((s) => s.orderId == orderId);
    }
    final masterKey = ref.read(keyManagerProvider).masterKeyPair!;
    final keyIndex = await ref.read(keyManagerProvider).getCurrentKeyIndex();
    final tradeKey = await ref.read(keyManagerProvider).deriveTradeKey();

    final session = Session(
      startTime: DateTime.now(),
      masterKey: masterKey,
      keyIndex: keyIndex,
      tradeKey: tradeKey,
      fullPrivacy: _settings.fullPrivacyMode,
      orderId: orderId,
      role: role,
    );

    if (orderId != null) {
      _sessions[orderId] = session;
      state = sessions;
    } else if (requestId != null) {
      _requestIdToSession[requestId] = session;
      state = [...sessions, session];
    }
    return session;
  }

  Future<void> saveSession(Session session) async {
    _sessions[session.orderId!] = session;
    await _storage.putSession(session);
    state = sessions;
  }

  Future<void> updateSession(
      String orderId, void Function(Session) update) async {
    final session = _sessions[orderId];
    if (session != null) {
      update(session);
      await _storage.putSession(session);
      state = sessions;
    }
  }

  Session? getSessionByRequestId(int requestId) {
    try {
      return _requestIdToSession[requestId];
    } on StateError {
      return null;
    }
  }

  Session? getSessionByOrderId(String orderId) {
    try {
      return _sessions[orderId];
    } on StateError {
      return null;
    }
  }

  Session? getSessionByTradeKey(String tradeKey) {
    try {
      return state.firstWhere(
        (s) => s.tradeKey.public == tradeKey,
      );
    } on StateError {
      return null;
    }
  }

  Future<Session?> loadSession(int keyIndex) async {
    final sessions = await _storage.getAllSessions();
    return sessions.firstWhere(
      (s) => s.keyIndex == keyIndex,
    );
  }

  Future<void> reset() async {
    await _storage.deleteAll();
    _sessions.clear();
    state = [];
  }

  Future<void> deleteSession(String sessionId) async {
    _sessions.remove(sessionId);
    await _storage.deleteSession(sessionId);
    state = sessions;
  }

  /// Clean up temporary session by requestId
  /// Used when order creation fails and needs retry
  void cleanupRequestSession(int requestId) {
    final session = _requestIdToSession.remove(requestId);
    if (session != null) {
      // Remove from state list if it was a temporary session
      final updatedSessions = sessions.where((s) => s != session).toList();
      state = updatedSessions;
      _logger.d('Cleaned up temporary session for requestId: $requestId');
    }
  }

  NostrKeyPairs calculateSharedKey(
      String tradePrivateKey, String counterpartyPublicKey) {
    try {
      final sharedKey =
          NostrUtils.computeSharedKey(tradePrivateKey, counterpartyPublicKey);

      // Avoid logging any part of the shared key to prevent leaking sensitive information
      _logger.d('Shared key calculated successfully');
      return sharedKey;
    } catch (e) {
      _logger.e('Error calculating shared key: $e');
      rethrow;
    }
  }

  Future<void> updateSessionWithSharedKey(
    String orderId,
    String counterpartyPublicKey,
  ) async {
    final session = getSessionByOrderId(orderId);
    if (session == null) {
      throw Exception('Session not found for orderId: $orderId');
    }

    final peer = Peer(publicKey: counterpartyPublicKey);
    session.peer = peer;

    await _storage.putSession(session);
    _sessions[orderId] = session;

    state = sessions;

    _logger.d('Session updated with shared key for orderId: $orderId');
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    super.dispose();
  }
}
