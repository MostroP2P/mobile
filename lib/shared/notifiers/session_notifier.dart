import 'dart:async';
import 'package:collection/collection.dart';
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
  // Holds sessions that represent the soon-to-arrive child order created
  // when releasing a range order. These do not have a definitive orderId yet
  // but we must start listening for messages encrypted to their trade key
  // immediately.
  final Map<String, Session> _pendingChildSessions = {};

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
    _emitState();
    _scheduleCleanup();
  }

  void _emitState() {
    final combined = <Session>[];
    combined.addAll(_sessions.values);
    combined.addAll(_requestIdToSession.values);
    combined.addAll(_pendingChildSessions.values);
    state = combined;
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

    _pendingChildSessions.removeWhere(
      (_, session) => session.startTime.isBefore(cutoff),
    );

    _emitState();
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
    } else if (requestId != null) {
      _requestIdToSession[requestId] = session;
    }

    _emitState();
    return session;
  }

  Future<void> saveSession(Session session) async {
    _sessions[session.orderId!] = session;
    _requestIdToSession.removeWhere((_, value) => identical(value, session));
    _pendingChildSessions.remove(session.tradeKey.public);
    await _storage.putSession(session);
    _emitState();
  }

  Future<void> updateSession(
      String orderId, void Function(Session) update) async {
    final session = _sessions[orderId];
    if (session != null) {
      update(session);
      await _storage.putSession(session);
      _emitState();
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
    return _sessions.values
            .firstWhereOrNull((s) => s.tradeKey.public == tradeKey) ??
        _pendingChildSessions[tradeKey] ??
        _requestIdToSession.values
            .firstWhereOrNull((s) => s.tradeKey.public == tradeKey);
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
    _pendingChildSessions.clear();
    _requestIdToSession.clear();
    state = [];
  }

  Future<void> deleteSession(String sessionId) async {
    final removed = _sessions.remove(sessionId);
    if (removed != null) {
      _pendingChildSessions
          .removeWhere((_, session) => identical(session, removed));
      _requestIdToSession
          .removeWhere((_, session) => identical(session, removed));
    }
    await _storage.deleteSession(sessionId);
    _emitState();
  }

  /// Delete session by requestId for timeout cleanup
  /// Used when create order timeout expires after 10s with no Mostro response
  Future<void> deleteSessionByRequestId(int requestId) async {
    _requestIdToSession.remove(requestId);
    // Note: No storage deletion - these are temporary sessions in memory only
    _emitState();
  }

  /// Clean up temporary session by requestId
  /// Used when order creation fails and needs retry
  void cleanupRequestSession(int requestId) {
    final session = _requestIdToSession.remove(requestId);
    if (session != null) {
      _pendingChildSessions
          .removeWhere((_, pending) => identical(pending, session));
      _sessions.removeWhere((_, stored) => identical(stored, session));
      _emitState();
      _logger.d('Cleaned up temporary session for requestId: $requestId');
    }
  }

  /// Create and register a child session that will represent the upcoming
  /// child order generated from a range order release.
  Future<Session> createChildOrderSession({
    required NostrKeyPairs tradeKey,
    required int keyIndex,
    required String parentOrderId,
    required Role role,
  }) async {
    final masterKey = ref.read(keyManagerProvider).masterKeyPair!;

    final session = Session(
      startTime: DateTime.now(),
      masterKey: masterKey,
      keyIndex: keyIndex,
      tradeKey: tradeKey,
      fullPrivacy: _settings.fullPrivacyMode,
      parentOrderId: parentOrderId,
      role: role,
    );

    _pendingChildSessions[tradeKey.public] = session;
    _emitState();

    _logger.i(
      'Prepared child session for parent order $parentOrderId using key index $keyIndex',
    );

    return session;
  }

  /// Link a previously prepared child session to the concrete child order id
  /// delivered by mostrod when the new child order arrives.
  Future<void> linkChildSessionToOrderId(
    String childOrderId,
    String tradeKeyPublic,
  ) async {
    final session = _pendingChildSessions.remove(tradeKeyPublic);
    if (session == null) {
      _logger.w(
        'No pending child session found for trade key $tradeKeyPublic; nothing to link.',
      );
      return;
    }

    session.orderId = childOrderId;
    _sessions[childOrderId] = session;
    await _storage.putSession(session);
    _emitState();

    _logger.i(
      'Linked child order $childOrderId to prepared session (parent: ${session.parentOrderId})',
    );
  }

  NostrKeyPairs calculateSharedKey(
      String tradePrivateKey, String counterpartyPublicKey) {
    try {
      final sharedKey =
          NostrUtils.computeSharedKey(tradePrivateKey, counterpartyPublicKey);

      _logger.d('Shared key calculated: ${sharedKey.public}');
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

    _emitState();

    _logger.d('Session updated with shared key for orderId: $orderId');
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    super.dispose();
  }
}
