import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/data/models/enums/role.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/repositories/session_storage.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:mostro_mobile/shared/providers/notifications_history_repository_provider.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:sembast/sembast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/services/push_notification_service.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/shared/utils/chat_keys.dart';
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

  /// Push notification service for registering tokens when sessions are saved
  PushNotificationService? _pushService;

  /// Set the push notification service for automatic token registration
  void setPushNotificationService(PushNotificationService? service) {
    _pushService = service;
  }

  List<Session> get sessions => _sessions.values.toList();

  SessionNotifier(
    this.ref,
    this._storage,
    this._settings,
  ) : super([]);

  int get _expirationHours =>
      _settings.sessionExpirationHours ?? Config.sessionExpirationHours;

  bool get _isForever => _expirationHours == 0;

  /// Removes the session's key material from the NIP-44 conversation-key
  /// cache: the trade key conversations (node, seals) and the chat `K_conv`
  /// self-conversations derived from the peer/admin shared keys. Without this
  /// the cache would retain secrets of retired sessions until process exit.
  void _evictSessionKeyMaterial(Session session) {
    NostrUtils.evictConversationKeysFor(session.tradeKey.private);
    final sharedKey = session.sharedKey;
    if (sharedKey != null) {
      NostrUtils.evictConversationKeysFor(
        ChatKeys.fromSharedKey(sharedKey).conv.private,
      );
    }
    final adminSharedKey = session.adminSharedKey;
    if (adminSharedKey != null) {
      NostrUtils.evictConversationKeysFor(
        ChatKeys.fromSharedKey(adminSharedKey).conv.private,
      );
    }
  }

  Future<void> _cleanupSessionData(Session session) async {
    final orderId = session.orderId;
    if (orderId == null) {
      logger.w('Skipping cleanup for session with null orderId');
      return;
    }
    final eventStore = ref.read(eventStorageProvider);
    final mostroStore = ref.read(mostroStorageProvider);
    final notificationsRepo = ref.read(notificationsRepositoryProvider);

    await eventStore.deleteWhere(Filter.equals('order_id', orderId));
    if (session.disputeId != null) {
      await eventStore.deleteWhere(
          Filter.equals('dispute_id', session.disputeId));
    }
    await mostroStore.deleteAllMessagesByOrderId(orderId);
    await notificationsRepo.deleteByOrderId(orderId);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('chat_last_read_$orderId');
    if (session.disputeId != null) {
      await prefs.remove('dispute_last_read_${session.disputeId}');
    }
  }

  /// Returns true if the session has an active (non-terminal) trade
  /// and should be protected from cleanup.
  Future<bool> _isActiveSession(Session session) async {
    final orderId = session.orderId;
    if (orderId == null) return false;
    final mostroStore = ref.read(mostroStorageProvider);
    final lastMessage = await mostroStore.getLatestMessageById(orderId);
    if (lastMessage == null) return false;
    final order = lastMessage.getPayload<Order>();
    return order != null && !order.status.isTerminal;
  }

  Future<void> init() async {
    final allSessions = await _storage.getAllSessions();
    if (_isForever) {
      for (final session in allSessions) {
        _sessions[session.orderId!] = session;
      }
    } else {
      final cutoff = DateTime.now()
          .subtract(Duration(hours: _expirationHours));
      for (final session in allSessions) {
        if (session.startTime.isAfter(cutoff)) {
          _sessions[session.orderId!] = session;
        } else {
          if (await _isActiveSession(session)) {
            logger.i('Skipping cleanup for active session ${session.orderId}');
            _sessions[session.orderId!] = session;
            continue;
          }
          await _storage.deleteSession(session.orderId!);
          _sessions.remove(session.orderId!);
          _evictSessionKeyMaterial(session);
          try {
            await _cleanupSessionData(session);
          } catch (e) {
            logger.e('Failed to cleanup data for session ${session.orderId}: $e');
          }
        }
      }
    }
    _emitState();
    _scheduleCleanup();
  }

  void _emitState() {
    // A session is reachable through three maps and only `_sessions` is keyed
    // by orderId, so the same order can otherwise surface twice (e.g. a
    // request-id session whose orderId was assigned by Mostro alongside the
    // persisted session the restore flow rebuilt for that same order). Every
    // consumer derived from this state — most visibly the chat list, which
    // renders one row per session — would then show the order twice.
    // `_sessions` holds the persisted session, so it wins.
    final combined = <Session>[];
    final claimedOrderIds = <String>{};
    for (final session in [
      ..._sessions.values,
      ..._requestIdToSession.values,
      ..._pendingChildSessions.values,
    ]) {
      final orderId = session.orderId;
      if (orderId != null && !claimedOrderIds.add(orderId)) continue;
      combined.add(session);
    }
    state = combined;
  }

  /// Drops every *other* in-memory session that carries [orderId] now that
  /// [owner] is the session of record for it. Identity is not enough: the
  /// restore flow rebuilds a brand new [Session] for an order that a pending
  /// request-id or child session may already point at.
  void _claimOrderId(String orderId, Session owner) {
    bool isStale(Session session) =>
        !identical(session, owner) && session.orderId == orderId;

    void logEviction(Session session) {
      // A differing trade key means the evicted session held key material no
      // other map can resolve any more, so surface it rather than dropping it
      // silently.
      if (session.tradeKey.public != owner.tradeKey.public) {
        logger.w(
          'Evicting session for order $orderId with a different trade key '
          '(${session.tradeKey.public}); it is no longer resolvable.',
        );
      } else {
        logger.d('Evicted a duplicate in-memory session for order $orderId');
      }
    }

    _requestIdToSession.removeWhere((_, session) {
      if (!isStale(session)) return false;
      logEviction(session);
      return true;
    });
    _pendingChildSessions.removeWhere((_, session) {
      if (!isStale(session)) return false;
      logEviction(session);
      return true;
    });
  }

  void _scheduleCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(
      const Duration(minutes: Config.cleanupIntervalMinutes),
      (timer) => _cleanup(),
    );
  }

  void _cleanup() async {
    if (_isForever) return;

    final cutoff = DateTime.now()
        .subtract(Duration(hours: _expirationHours));
    // Iterate the in-memory sessions: getAllSessions() re-decoded every row,
    // re-running trade-key derivation per session every 30 minutes.
    final candidates = _sessions.values.toList();

    for (final session in candidates) {
      if (session.startTime.isBefore(cutoff)) {
        if (await _isActiveSession(session)) {
          logger.i('Skipping cleanup for active session ${session.orderId}');
          continue;
        }
        await _storage.deleteSession(session.orderId!);
        _sessions.remove(session.orderId!);
        _evictSessionKeyMaterial(session);
        try {
          await _cleanupSessionData(session);
        } catch (e) {
          logger.e('Failed to cleanup data for session ${session.orderId}: $e');
        }
      }
    }

    _pendingChildSessions.removeWhere((_, session) {
      final expired = session.startTime.isBefore(cutoff);
      if (expired) _evictSessionKeyMaterial(session);
      return expired;
    });

    _emitState();
  }

  void updateSettings(Settings settings) {
    _settings = settings.copyWith();
  }

  Future<Session> newSession(
      {String? orderId, int? requestId, Role? role}) async {
    if (orderId != null && state.any((s) => s.orderId == orderId)) {
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
      _claimOrderId(orderId, session);
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
    _claimOrderId(session.orderId!, session);
    await _storage.putSession(session);
    _emitState();

    // Register push notification token for this trade
    _registerPushToken(session.tradeKey.public);
  }

  /// Registers [session] in memory keyed by its orderId WITHOUT persisting it
  /// to disk. Used for the maker anti-abuse bond limbo: the order is not yet
  /// committed, so it stays ephemeral (gone on restart) while remaining
  /// reachable by orderId for the pay-bond screen and cancel flow. The session
  /// is persisted for real only once the order is confirmed via saveSession.
  void registerSessionInMemory(Session session) {
    final orderId = session.orderId;
    if (orderId == null) return;
    _sessions[orderId] = session;
    _requestIdToSession.removeWhere((_, value) => identical(value, session));
    _claimOrderId(orderId, session);
    _emitState();
  }

  /// Register push notification token for a trade pubkey
  void _registerPushToken(String tradePubkey) {
    if (_pushService == null) {
      logger.d('Push service not available, skipping token registration');
      return;
    }

    // Fire and forget - don't block session save on push registration
    _pushService!.registerToken(tradePubkey).then((success) {
      if (success) {
        logger.i('Push token registered for trade: ${tradePubkey.substring(0, 16)}...');
      }
    }).catchError((e) {
      logger.w('Failed to register push token: $e');
    });
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
    NostrUtils.clearConversationKeyCache();
    state = [];
  }

  Future<void> deleteSession(String sessionId) async {
    final removed = _sessions.remove(sessionId);
    if (removed != null) {
      _pendingChildSessions
          .removeWhere((_, session) => identical(session, removed));
      _requestIdToSession
          .removeWhere((_, session) => identical(session, removed));
      _evictSessionKeyMaterial(removed);
    }
    await _storage.deleteSession(sessionId);
    _emitState();
  }

  /// Delete session by requestId for timeout cleanup
  /// Used when create order timeout expires after 10s with no Mostro response
  Future<void> deleteSessionByRequestId(int requestId) async {
    final removed = _requestIdToSession.remove(requestId);
    if (removed != null) {
      _evictSessionKeyMaterial(removed);
    }
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
      _evictSessionKeyMaterial(session);
      _emitState();
      logger.d('Cleaned up temporary session for requestId: $requestId');
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

    // Register the child trade key with the push server right away: the child
    // order can be taken as soon as mostrod publishes it, and without this
    // mapping the push server cannot wake the device (FCM) for events
    // addressed to the child trade key while the app is killed or dozing.
    _registerPushToken(tradeKey.public);

    logger.i(
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
      logger.w(
        'No pending child session found for trade key $tradeKeyPublic; nothing to link.',
      );
      return;
    }

    session.orderId = childOrderId;
    _sessions[childOrderId] = session;
    _claimOrderId(childOrderId, session);
    await _storage.putSession(session);
    _emitState();

    // Retry the push registration on link in case the creation-time attempt
    // failed (e.g. offline right after release). registerToken is idempotent
    // server-side, so a duplicate call is harmless.
    _registerPushToken(session.tradeKey.public);

    logger.i(
      'Linked child order $childOrderId to prepared session (parent: ${session.parentOrderId})',
    );
  }

  NostrKeyPairs calculateSharedKey(
      String tradePrivateKey, String counterpartyPublicKey) {
    try {
      final sharedKey =
          NostrUtils.computeSharedKey(tradePrivateKey, counterpartyPublicKey);

      logger.d('Shared key calculated: ${sharedKey.public}');
      return sharedKey;
    } catch (e) {
      logger.e('Error calculating shared key: $e');
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

    logger.d('Session updated with shared key for orderId: $orderId');
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    super.dispose();
  }
}
