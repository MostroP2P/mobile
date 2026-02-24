import 'dart:async';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/data/models/dispute_chat.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/disputes/providers/dispute_providers.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:sembast/sembast.dart';

/// State for dispute chat messages
class DisputeChatState {
  final List<DisputeChat> messages;
  final bool isLoading;
  final String? error;

  const DisputeChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  DisputeChatState copyWith({
    List<DisputeChat>? messages,
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
/// Uses shared key encryption (p2pWrap/p2pUnwrap) with admin via ECDH
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

  /// Handle incoming chat events via p2pUnwrap
  void _onChatEvent(NostrEvent event) async {
    try {
      if (event.kind != 1059) {
        return;
      }

      final session = _getSessionForDispute();
      if (session == null || session.adminSharedKey == null) {
        return;
      }

      // Verify p tag matches admin shared key
      final pTag = event.tags?.firstWhere(
        (tag) => tag.isNotEmpty && tag[0] == 'p',
        orElse: () => [],
      ) ?? [];
      if (pTag.isEmpty || pTag.length < 2 || pTag[1] != session.adminSharedKey!.public) {
        return;
      }

      // Check for duplicate events
      final wrapperEventId = event.id;
      if (wrapperEventId == null) return;
      final eventStore = ref.read(eventStorageProvider);
      if (await eventStore.hasItem(wrapperEventId)) {
        return;
      }

      // Unwrap using admin shared key (1-layer p2p decryption)
      final unwrappedEvent = await event.p2pUnwrap(session.adminSharedKey!);

      // Content is plain text (no MostroMessage JSON wrapper)
      final messageText = unwrappedEvent.content ?? '';
      if (messageText.isEmpty) {
        logger.w('Received empty message, skipping');
        return;
      }

      final senderPubkey = unwrappedEvent.pubkey;
      final isFromAdmin = senderPubkey != session.tradeKey.public;

      // SECURITY: Validate sender pubkey for admin messages
      if (isFromAdmin) {
        final dispute = await ref.read(disputeDetailsProvider(disputeId).future);
        if (dispute?.adminPubkey == null) {
          logger.w('Rejecting admin message for dispute $disputeId: '
              'adminPubkey not yet available (possible race with adminTookDispute). '
              'eventId=${event.id}, sender=$senderPubkey');
          return;
        }
        if (senderPubkey != dispute!.adminPubkey) {
          logger.w('SECURITY: Rejecting message from unauthorized pubkey: '
              '$senderPubkey (expected: ${dispute.adminPubkey}), '
              'eventId=${event.id}, dispute=$disputeId');
          return;
        }
      }

      final eventId = unwrappedEvent.id ?? event.id ?? 'chat_${DateTime.now().millisecondsSinceEpoch}_${messageText.hashCode}';
      final eventTimestamp = unwrappedEvent.createdAt ?? DateTime.now();

      // Store the event
      await eventStore.putItem(
        eventId,
        {
          'id': eventId,
          'content': messageText,
          'created_at': eventTimestamp.millisecondsSinceEpoch ~/ 1000,
          'kind': unwrappedEvent.kind,
          'pubkey': senderPubkey,
          'sig': unwrappedEvent.sig,
          'tags': unwrappedEvent.tags,
          'type': 'dispute_chat',
          'dispute_id': disputeId,
          'is_from_user': !isFromAdmin,
          'isPending': false,
        },
      );

      // Add to state
      final disputeChat = DisputeChat(
        id: eventId,
        message: messageText,
        timestamp: eventTimestamp,
        isFromUser: !isFromAdmin,
        adminPubkey: isFromAdmin ? senderPubkey : null,
        isPending: false,
      );

      final allMessages = [...state.messages, disputeChat];
      final deduped = {for (var m in allMessages) m.id: m}.values.toList();
      deduped.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      state = state.copyWith(messages: deduped);
      logger.i('Added dispute chat message for dispute: $disputeId (from ${isFromAdmin ? "admin" : "user"})');
    } catch (e, stackTrace) {
      logger.e('Error processing dispute chat event: $e', stackTrace: stackTrace);
    }
  }

  /// Load historical messages from storage
  Future<void> _loadHistoricalMessages() async {
    try {
      logger.i('Loading historical messages for dispute: $disputeId');
      state = state.copyWith(isLoading: true);

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

      final dispute = await ref.read(disputeDetailsProvider(disputeId).future);

      final List<DisputeChat> messages = [];
      int filteredCount = 0;

      for (final eventData in chatEvents) {
        try {
          final isFromUser = eventData['is_from_user'] as bool? ?? true;
          final messagePubkey = eventData['pubkey'] as String?;

          // SECURITY: Filter messages by authorized pubkeys
          if (!isFromUser) {
            if (dispute?.adminPubkey == null) {
              filteredCount++;
              continue;
            }
            if (messagePubkey == null || messagePubkey != dispute!.adminPubkey) {
              logger.w('SECURITY: Filtering historical message from unauthorized pubkey: $messagePubkey');
              filteredCount++;
              continue;
            }
          }

          messages.add(DisputeChat(
            id: eventData['id'] as String,
            message: eventData['content'] as String? ?? '',
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              (eventData['created_at'] as int) * 1000,
            ),
            isFromUser: isFromUser,
            adminPubkey: eventData['admin_pubkey'] as String?,
            isPending: eventData['isPending'] as bool? ?? false,
            error: eventData['error'] as String?,
          ));
        } catch (e) {
          logger.w('Failed to parse dispute chat message: $e');
        }
      }

      if (filteredCount > 0) {
        logger.i('Filtered $filteredCount unauthorized messages from dispute $disputeId');
      }

      state = state.copyWith(messages: messages, isLoading: false);
    } catch (e, stackTrace) {
      logger.e('Error loading historical messages: $e', stackTrace: stackTrace);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Send a message in the dispute chat using p2pWrap with admin shared key
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

    final orderId = session.orderId;
    if (orderId == null) {
      logger.w('Cannot send message: Session orderId is null');
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
    final rumorTimestamp = rumor.createdAt ?? DateTime.now();

    try {
      logger.i('Sending p2pWrap DM to admin via shared key for dispute: $disputeId');

      // Add message to state with isPending=true (optimistic UI)
      // Uses the real rumor ID so relay echo deduplication works correctly
      final pendingMessage = DisputeChat(
        id: rumorId,
        message: text,
        timestamp: rumorTimestamp,
        isFromUser: true,
        isPending: true,
      );

      final allMessages = [...state.messages, pendingMessage];
      final deduped = {for (var m in allMessages) m.id: m}.values.toList();
      deduped.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      state = state.copyWith(messages: deduped, error: null);

      // Wrap using p2pWrap (1-layer, shared key routing)
      final wrappedEvent = await rumor.p2pWrap(
        session.tradeKey,
        session.adminSharedKey!.public,
      );

      logger.i('Sending p2pWrap from ${session.tradeKey.public} via shared key ${session.adminSharedKey!.public}');

      // Publish to network
      try {
        await ref.read(nostrServiceProvider).publishEvent(wrappedEvent);
        logger.i('Dispute message sent successfully for dispute: $disputeId');
      } catch (publishError, publishStack) {
        logger.e('Failed to publish dispute message: $publishError', stackTrace: publishStack);

        final failedMessage = pendingMessage.copyWith(
          isPending: false,
          error: 'Failed to publish: $publishError',
        );
        final updatedMessages = state.messages.map((m) => m.id == rumorId ? failedMessage : m).toList();
        state = state.copyWith(
          messages: updatedMessages,
          error: 'Failed to send message: $publishError',
        );

        final eventStore = ref.read(eventStorageProvider);
        try {
          await eventStore.putItem(
            rumorId,
            {
              'id': rumorId,
              'content': text,
              'created_at': rumorTimestamp.millisecondsSinceEpoch ~/ 1000,
              'kind': rumor.kind,
              'pubkey': rumor.pubkey,
              'type': 'dispute_chat',
              'dispute_id': disputeId,
              'is_from_user': true,
              'isPending': false,
              'error': 'Failed to publish: $publishError',
            },
          );
        } catch (storageError) {
          logger.e('Failed to store error state: $storageError');
        }
        return;
      }

      // Update message to isPending=false (success)
      final sentMessage = pendingMessage.copyWith(isPending: false);
      final updatedMessages = state.messages.map((m) => m.id == rumorId ? sentMessage : m).toList();
      state = state.copyWith(messages: updatedMessages);

      // Store in local storage
      final eventStore = ref.read(eventStorageProvider);
      await eventStore.putItem(
        rumorId,
        {
          'id': rumorId,
          'content': text,
          'created_at': rumorTimestamp.millisecondsSinceEpoch ~/ 1000,
          'kind': rumor.kind,
          'pubkey': rumor.pubkey,
          'sig': rumor.sig,
          'tags': rumor.tags,
          'type': 'dispute_chat',
          'dispute_id': disputeId,
          'is_from_user': true,
          'isPending': false,
        },
      );
    } catch (e, stackTrace) {
      logger.e('Failed to send dispute message: $e', stackTrace: stackTrace);

      final failedMessage = state.messages
          .firstWhere((m) => m.id == rumorId, orElse: () => DisputeChat(
                id: rumorId,
                message: text,
                timestamp: rumorTimestamp,
                isFromUser: true,
              ))
          .copyWith(isPending: false, error: e.toString());

      final updatedMessages = state.messages.map((m) => m.id == rumorId ? failedMessage : m).toList();
      state = state.copyWith(
        messages: updatedMessages,
        error: 'Failed to send message: $e',
      );

      final eventStore = ref.read(eventStorageProvider);
      try {
        await eventStore.putItem(
          rumorId,
          {
            'id': rumorId,
            'content': text,
            'created_at': rumorTimestamp.millisecondsSinceEpoch ~/ 1000,
            'kind': 1,
            'pubkey': session.tradeKey.public,
            'type': 'dispute_chat',
            'dispute_id': disputeId,
            'is_from_user': true,
            'isPending': false,
            'error': e.toString(),
          },
        );
      } catch (storageError) {
        logger.e('Failed to store error state: $storageError');
      }
    }
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
