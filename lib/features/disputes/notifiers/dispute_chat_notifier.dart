import 'dart:async';
import 'dart:typed_data';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:sembast/sembast.dart';

/// Thin wrapper around NostrEvent with UI-only pending/error state
class DisputeChatMessage {
  final NostrEvent event;
  final bool isPending;
  final String? error;

  const DisputeChatMessage({
    required this.event,
    this.isPending = false,
    this.error,
  });

  String get id => event.id ?? '';
  String get content => event.content ?? '';
  DateTime get timestamp => event.createdAt ?? DateTime.now();

  DisputeChatMessage copyWith({
    NostrEvent? event,
    bool? isPending,
    String? error,
  }) {
    return DisputeChatMessage(
      event: event ?? this.event,
      isPending: isPending ?? this.isPending,
      error: error ?? this.error,
    );
  }
}

/// State for dispute chat messages
class DisputeChatState {
  final List<DisputeChatMessage> messages;
  final bool isLoading;
  final String? error;

  const DisputeChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  DisputeChatState copyWith({
    List<DisputeChatMessage>? messages,
    bool? isLoading,
    String? error,
  }) {
    return DisputeChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Notifier for dispute chat messages
/// Uses shared key encryption (p2pWrap/p2pUnwrap) with admin via ECDH.
/// Stores gift wrap events (encrypted) on disk, same pattern as P2P chat.
class DisputeChatNotifier extends StateNotifier<DisputeChatState> {
  final String disputeId;
  final Ref ref;

  StreamSubscription<NostrEvent>? _subscription;
  ProviderSubscription<dynamic>? _sessionListener;
  bool _isInitialized = false;

  DisputeChatNotifier(this.disputeId, this.ref) : super(const DisputeChatState());

  /// Initialize the dispute chat by loading historical messages and subscribing to new events
  Future<void> initialize() async {
    if (_isInitialized) return;

    logger.i('Initializing dispute chat for disputeId: $disputeId');
    await _loadHistoricalMessages();
    await _subscribe();
    _isInitialized = true;
  }

  /// Subscribe to new dispute chat messages using admin shared key
  Future<void> _subscribe() async {
    final session = _getSessionForDispute();
    if (session == null) {
      logger.w('No session found for dispute: $disputeId');
      _listenForSession();
      return;
    }

    if (session.adminSharedKey == null) {
      logger.w('Admin shared key not available yet for dispute: $disputeId');
      _listenForSession();
      return;
    }

    // Cancel existing subscription to prevent leaks and duplicate handlers
    if (_subscription != null) {
      logger.i('Cancelling previous subscription for dispute: $disputeId');
      await _subscription!.cancel();
      _subscription = null;
    }

    // Subscribe to kind 1059 (Gift Wrap) events routed to admin shared key
    final nostrService = ref.read(nostrServiceProvider);
    final request = NostrRequest(
      filters: [
        NostrFilter(
          kinds: [1059],
          p: [session.adminSharedKey!.public],
        ),
      ],
    );

    _subscription = nostrService.subscribeToEvents(request).listen(_onChatEvent);
    logger.i('Subscribed to kind 1059 via admin shared key for dispute: $disputeId');
  }

  /// Listen for session changes and subscribe when admin shared key is ready
  void _listenForSession() {
    // Cancel any previous listener to avoid leaks
    _sessionListener?.close();
    _sessionListener = null;

    logger.i('Listening for session changes (admin shared key) for dispute: $disputeId');

    // Watch the entire session list for changes
    _sessionListener = ref.listen<List<Session>>(
      sessionNotifierProvider,
      (previous, next) {
        final session = _getSessionForDispute();
        if (session != null && session.adminSharedKey != null) {
          logger.i('Admin shared key available for dispute $disputeId, subscribing');
          _sessionListener?.close();
          _sessionListener = null;
          unawaited(_subscribe());
        }
      },
    );
  }

  /// Handle incoming chat events via p2pUnwrap.
  /// Stores the gift wrap event (encrypted) to disk, then unwraps for display.
  void _onChatEvent(NostrEvent event) async {
    try {
      if (event.kind != 1059) return;

      final session = _getSessionForDispute();
      if (session == null || session.adminSharedKey == null) return;

      // Verify p tag matches admin shared key
      final pTag = event.tags?.firstWhere(
        (tag) => tag.isNotEmpty && tag[0] == 'p',
        orElse: () => [],
      ) ?? [];
      if (pTag.isEmpty || pTag.length < 2 || pTag[1] != session.adminSharedKey!.public) {
        return;
      }

      // Check for duplicate gift wrap events
      final wrapperEventId = event.id;
      if (wrapperEventId == null) return;
      final eventStore = ref.read(eventStorageProvider);
      if (await eventStore.hasItem(wrapperEventId)) return;

      // Store the gift wrap event (encrypted) to disk — same pattern as P2P chat
      await eventStore.putItem(
        wrapperEventId,
        {
          'id': wrapperEventId,
          'created_at': event.createdAt!.millisecondsSinceEpoch ~/ 1000,
          'kind': event.kind,
          'content': event.content,
          'pubkey': event.pubkey,
          'sig': event.sig,
          'tags': event.tags,
          'type': 'dispute_chat',
          'dispute_id': disputeId,
        },
      );

      // Unwrap using admin shared key (1-layer p2p decryption)
      final unwrappedEvent = await event.p2pUnwrap(session.adminSharedKey!);

      // SECURITY: The ECDH shared key IS the authentication.
      // If p2pUnwrap succeeded, the sender holds the admin's private key.

      final messageText = unwrappedEvent.content ?? '';
      if (messageText.isEmpty) {
        logger.w('Received empty message, skipping');
        return;
      }

      final isFromAdmin = unwrappedEvent.pubkey != session.tradeKey.public;
      final message = DisputeChatMessage(event: unwrappedEvent);

      // Dedup by inner event ID (handles relay echo of sent messages)
      final allMessages = [...state.messages, message];
      final deduped = {for (var m in allMessages) m.id: m}.values.toList();
      deduped.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      state = state.copyWith(messages: deduped);
      logger.i('Added dispute chat message for dispute: $disputeId '
          '(from ${isFromAdmin ? "admin" : "user"})');
    } catch (e, stackTrace) {
      logger.e('Error processing dispute chat event: $e', stackTrace: stackTrace);
    }
  }

  /// Load historical messages from storage.
  /// Reconstructs gift wrap events and unwraps them with adminSharedKey.
  Future<void> _loadHistoricalMessages() async {
    try {
      logger.i('Loading historical messages for dispute: $disputeId');
      state = state.copyWith(isLoading: true);

      final session = _getSessionForDispute();
      if (session == null || session.adminSharedKey == null) {
        logger.i('Admin shared key not available, skipping historical load');
        state = state.copyWith(isLoading: false);
        return;
      }

      final eventStore = ref.read(eventStorageProvider);

      // Find all dispute chat events for this dispute
      final chatEvents = await eventStore.find(
        filter: Filter.and([
          eventStore.eq('type', 'dispute_chat'),
          eventStore.eq('dispute_id', disputeId),
        ]),
        sort: [SortOrder('created_at', true)],
      );

      logger.i('Found ${chatEvents.length} historical messages for dispute: $disputeId');

      final List<DisputeChatMessage> messages = [];

      for (final eventData in chatEvents) {
        try {
          // Check if this is a complete gift wrap event (has all required fields)
          final hasCompleteData = eventData.containsKey('kind') &&
              eventData.containsKey('content') &&
              eventData.containsKey('pubkey') &&
              eventData.containsKey('sig') &&
              eventData.containsKey('tags');

          if (!hasCompleteData) {
            logger.w('Event ${eventData['id']} is incomplete, skipping');
            continue;
          }

          // Reconstruct the gift wrap NostrEvent from stored data
          final storedEvent = NostrEventExtensions.fromMap({
            'id': eventData['id'],
            'created_at': eventData['created_at'],
            'kind': eventData['kind'],
            'content': eventData['content'],
            'pubkey': eventData['pubkey'],
            'sig': eventData['sig'],
            'tags': eventData['tags'],
          });

          // Verify p tag matches our admin shared key
          if (session.adminSharedKey!.public != storedEvent.recipient) {
            continue;
          }

          // Decrypt and unwrap the message
          final unwrappedEvent = await storedEvent.p2pUnwrap(session.adminSharedKey!);
          messages.add(DisputeChatMessage(event: unwrappedEvent));
        } catch (e) {
          logger.w('Failed to process historical dispute event ${eventData['id']}: $e');
        }
      }

      // Dedup by inner event ID
      final deduped = {for (var m in messages) m.id: m}.values.toList();
      deduped.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      state = state.copyWith(messages: deduped, isLoading: false);
    } catch (e, stackTrace) {
      logger.e('Error loading historical messages: $e', stackTrace: stackTrace);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Send a message in the dispute chat using p2pWrap with admin shared key.
  /// Stores the gift wrap event (encrypted) on success.
  Future<void> sendMessage(String text) async {
    final session = _getSessionForDispute();
    if (session == null) {
      logger.w('Cannot send message: Session is null for dispute: $disputeId');
      return;
    }

    if (session.adminSharedKey == null) {
      logger.w('Cannot send message: Admin shared key not available for dispute: $disputeId');
      return;
    }

    // Create rumor (kind 1) with plain text content FIRST to get real event ID
    final rumor = NostrEvent.fromPartialData(
      keyPairs: session.tradeKey,
      content: text,
      kind: 1,
      tags: [
        ["p", session.adminSharedKey!.public],
      ],
    );

    final rumorId = rumor.id;
    if (rumorId == null) {
      logger.e('Failed to compute rumor ID for dispute: $disputeId');
      state = state.copyWith(error: 'Failed to prepare message');
      return;
    }

    try {
      // Add message to state with isPending=true (optimistic UI)
      // Uses the real rumor ID so relay echo deduplication works correctly
      final pendingMessage = DisputeChatMessage(event: rumor, isPending: true);

      final allMessages = [...state.messages, pendingMessage];
      final deduped = {for (var m in allMessages) m.id: m}.values.toList();
      deduped.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      state = state.copyWith(messages: deduped, error: null);

      // Wrap using p2pWrap (1-layer, shared key routing)
      final wrappedEvent = await rumor.p2pWrap(
        session.tradeKey,
        session.adminSharedKey!.public,
      );

      // Publish to network
      try {
        await ref.read(nostrServiceProvider).publishEvent(wrappedEvent);
        logger.i('Dispute message sent successfully for dispute: $disputeId');
      } catch (publishError, publishStack) {
        logger.e('Failed to publish dispute message: $publishError',
            stackTrace: publishStack);
        _updateMessageState(rumorId, isPending: false, error: 'Failed to publish: $publishError');
        return;
      }

      // On success: store the gift wrap event (encrypted) to disk
      final eventStore = ref.read(eventStorageProvider);
      await eventStore.putItem(
        wrappedEvent.id!,
        {
          'id': wrappedEvent.id,
          'created_at': wrappedEvent.createdAt!.millisecondsSinceEpoch ~/ 1000,
          'kind': wrappedEvent.kind,
          'content': wrappedEvent.content,
          'pubkey': wrappedEvent.pubkey,
          'sig': wrappedEvent.sig,
          'tags': wrappedEvent.tags,
          'type': 'dispute_chat',
          'dispute_id': disputeId,
        },
      );

      // Update message to isPending=false (success)
      _updateMessageState(rumorId, isPending: false);
    } catch (e, stackTrace) {
      logger.e('Failed to send dispute message: $e', stackTrace: stackTrace);
      _updateMessageState(rumorId, isPending: false, error: e.toString());
    }
  }

  /// Update a message's pending/error state in the current state.
  /// Per-message errors stay at message level; state.error is reserved
  /// for initialization/loading failures only.
  void _updateMessageState(String messageId, {required bool isPending, String? error}) {
    final updatedMessages = state.messages.map((m) {
      if (m.id == messageId) {
        return DisputeChatMessage(
          event: m.event,
          isPending: isPending,
          error: error,
        );
      }
      return m;
    }).toList();
    state = state.copyWith(messages: updatedMessages);
  }

  /// Get the admin shared key as raw bytes for multimedia encryption
  Future<Uint8List> getAdminSharedKey() async {
    final session = _getSessionForDispute();
    if (session == null || session.adminSharedKey == null) {
      throw Exception('Admin shared key not available for dispute: $disputeId');
    }

    final hexKey = session.adminSharedKey!.private;
    if (hexKey.length != 64) {
      throw Exception('Invalid admin shared key length: expected 64 hex chars, '
          'got ${hexKey.length}');
    }

    final bytes = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      bytes[i] = int.parse(hexKey.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  /// Determine if a message is from the current user
  bool isFromUser(DisputeChatMessage message) {
    final session = _getSessionForDispute();
    if (session == null) return false;
    return message.event.pubkey == session.tradeKey.public;
  }

  /// Get the session for this dispute
  Session? _getSessionForDispute() {
    try {
      final sessions = ref.read(sessionNotifierProvider);

      for (final session in sessions) {
        if (session.orderId != null) {
          try {
            final orderState = ref.read(orderNotifierProvider(session.orderId!));
            if (orderState.dispute?.disputeId == disputeId) {
              return session;
            }
          } catch (e) {
            continue;
          }
        }
      }

      logger.w('No session found matching disputeId: $disputeId');
      return null;
    } catch (e, stackTrace) {
      logger.e('Error getting session for dispute: $e', stackTrace: stackTrace);
      return null;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _sessionListener?.close();
    super.dispose();
  }
}

final disputeChatNotifierProvider =
    StateNotifierProvider.family<DisputeChatNotifier, DisputeChatState, String>(
  (ref, disputeId) {
    final notifier = DisputeChatNotifier(disputeId, ref);
    unawaited(notifier.initialize());
    return notifier;
  },
);
