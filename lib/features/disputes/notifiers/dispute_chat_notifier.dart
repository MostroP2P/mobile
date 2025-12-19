import 'dart:async';
import 'dart:convert';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/data/models/dispute_chat.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/models/text_message.dart';
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

  /// Subscribe to new dispute chat messages
  Future<void> _subscribe() async {
    final session = _getSessionForDispute();
    if (session == null) {
      logger.w('No session found for dispute: $disputeId');
      _listenForSession();
      return;
    }

    // Cancel existing subscription to prevent leaks and duplicate handlers
    if (_subscription != null) {
      logger.i('Cancelling previous subscription for dispute: $disputeId');
      await _subscription!.cancel();
      _subscription = null;
    }

    // Subscribe to kind 1059 (Gift Wrap) events for dispute messages
    final nostrService = ref.read(nostrServiceProvider);
    final request = NostrRequest(
      filters: [
        NostrFilter(
          kinds: [1059], // Gift Wrap
          p: [session.tradeKey.public], // Messages to our tradeKey
        ),
      ],
    );
    
    _subscription = nostrService.subscribeToEvents(request).listen(_onChatEvent);
    logger.i('Subscribed to kind 1059 (Gift Wrap) for dispute: $disputeId');
  }

  /// Listen for session changes and subscribe when session is ready
  void _listenForSession() {
    // Cancel any previous listener to avoid leaks
    _sessionListener?.close();
    _sessionListener = null;
    
    logger.i('Starting to listen for session list changes for dispute: $disputeId');

    // Watch the entire session list for changes
    _sessionListener = ref.listen<List<Session>>(
      sessionNotifierProvider,
      (previous, next) {
        logger.i('Session list changed, checking for dispute $disputeId match');
        
        // Try to find a session that matches this dispute
        final session = _getSessionForDispute();
        if (session != null) {
          // Found a matching session, cancel listener and subscribe
          logger.i('Session found for dispute $disputeId, canceling listener and subscribing');
          _sessionListener?.close();
          _sessionListener = null;
          unawaited(_subscribe());
        }
      },
    );
  }

  /// Handle incoming chat events
  void _onChatEvent(NostrEvent event) async {
    try {
      // Check for kind 1059 (Gift Wrap)
      if (event.kind != 1059) {
        return;
      }

      final session = _getSessionForDispute();
      if (session == null) {
        return;
      }
      
      // Check if this message belongs to this dispute
      final dispute = await ref.read(disputeDetailsProvider(disputeId).future);
      if (dispute == null) {
        return;
      }
      
      // Unwrap the gift wrap using trade key (following NIP-59)
      // The mostroUnWrap will handle the two-layer decryption automatically
      final unwrappedEvent = await event.mostroUnWrap(session.tradeKey);

      // Parse the Mostro message from the rumor content
      String messageText = '';
      String? senderPubkey;
      bool isFromAdmin = false;
      
      try {
        // Content can be in two formats:
        // 1. CLI format: [{"dm": {"version": 1, "action": "send-dm", "payload": {"text_message": "..."}}}, null]
        // 2. Old format: [{"order": {...}}, null] or [{"version": 1, "action": "send-dm", ...}, null]
        final contentData = jsonDecode(unwrappedEvent.content ?? '[]');
        if (contentData is List && contentData.isNotEmpty) {
          final messageData = contentData[0];
          
          // Check if it's the CLI format with Message enum (has "dm" key)
          if (messageData is Map && messageData.containsKey('dm')) {
            final dmData = messageData['dm'];
            if (dmData is Map && dmData.containsKey('payload')) {
              final payload = dmData['payload'];
              if (payload is Map && payload.containsKey('text_message')) {
                messageText = payload['text_message'] as String;
                senderPubkey = unwrappedEvent.pubkey;
                isFromAdmin = senderPubkey != session.tradeKey.public;
              }
            }
          } else {
            // Try parsing as old MostroMessage format
            final mostroMessage = MostroMessage.fromJson(messageData);
            
            // Only process send-dm actions
            if (mostroMessage.action != Action.sendDm) {
              return;
            }
            
            // Extract text from TextMessage payload
            if (mostroMessage.payload != null) {
              final textPayload = mostroMessage.getPayload<TextMessage>();
              if (textPayload != null) {
                messageText = textPayload.message;
                senderPubkey = unwrappedEvent.pubkey;
                isFromAdmin = senderPubkey != session.tradeKey.public;
              }
            }
          }
        }
      } catch (e) {
        logger.w('Failed to parse Mostro message: $e');
        return;
      }

      if (messageText.isEmpty) {
        logger.w('Received empty message, skipping');
        return;
      }

      // SECURITY: Validate sender pubkey
      // Only accept messages from:
      // 1. The user themselves (session.tradeKey.public)
      // 2. The assigned admin/solver (dispute.adminPubkey)
      if (isFromAdmin) {
        if (dispute.adminPubkey == null) {
          logger.w('Rejecting message: No admin assigned yet for dispute $disputeId');
          return;
        }
        
        if (senderPubkey != dispute.adminPubkey) {
          logger.w('SECURITY: Rejecting message from unauthorized pubkey: $senderPubkey (expected admin: ${dispute.adminPubkey})');
          return;
        }
        
        logger.i('Validated message from authorized admin: $senderPubkey');
      }

      // Generate event ID if not present (can happen with admin messages)
      final eventId = unwrappedEvent.id ?? event.id ?? 'chat_${DateTime.now().millisecondsSinceEpoch}_${messageText.hashCode}';
      final eventTimestamp = unwrappedEvent.createdAt ?? DateTime.now();
      
      // Store the event
      final eventStore = ref.read(eventStorageProvider);
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
        isPending: false, // Received messages are already confirmed
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
        sort: [SortOrder('created_at', true)], // Oldest first
      );

      logger.i('Found ${chatEvents.length} historical messages for dispute: $disputeId');

      // Get dispute to validate admin pubkey
      final dispute = await ref.read(disputeDetailsProvider(disputeId).future);

      final List<DisputeChat> messages = [];
      int filteredCount = 0;
      
      for (final eventData in chatEvents) {
        try {
          final isFromUser = eventData['is_from_user'] as bool? ?? true;
          final messagePubkey = eventData['pubkey'] as String?;
          
          // SECURITY: Filter messages by authorized pubkeys
          // Only include messages from:
          // 1. The user themselves (is_from_user = true)
          // 2. The assigned admin/solver (matches dispute.adminPubkey)
          if (!isFromUser) {
            // Message is from admin, validate pubkey
            if (dispute?.adminPubkey == null) {
              logger.w('Filtering historical message: No admin assigned yet');
              filteredCount++;
              continue;
            }
            
            if (messagePubkey != null && messagePubkey != dispute!.adminPubkey) {
              logger.w('SECURITY: Filtering historical message from unauthorized pubkey: $messagePubkey (expected: ${dispute.adminPubkey})');
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

  /// Send a message in the dispute chat
  /// Uses Gift Wrap (NIP-59) with MostroMessage format like mostro-cli
  Future<void> sendMessage(String text) async {
    final session = _getSessionForDispute();
    if (session == null) {
      logger.w('Cannot send message: Session is null for dispute: $disputeId');
      return;
    }

    // Get dispute to find admin pubkey and orderId
    final dispute = await ref.read(disputeDetailsProvider(disputeId).future);
    if (dispute == null) {
      logger.w('Cannot send message: Dispute not found');
      return;
    }
    
    if (dispute.adminPubkey == null) {
      logger.w('Cannot send message: Admin pubkey not found for dispute');
      return;
    }
    
    // Get orderId from session
    final orderId = session.orderId;
    if (orderId == null) {
      logger.w('Cannot send message: Session orderId is null');
      return;
    }

    // Generate ID for message
    final rumorId = 'rumor_${DateTime.now().millisecondsSinceEpoch}';
    final rumorTimestamp = DateTime.now();

    try {
      logger.i('Sending Gift Wrap DM to admin: ${dispute.adminPubkey}');
      
      // Add message to state with isPending=true (optimistic UI)
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

      // For dispute chat, the CLI expects format matching Message enum from mostro-core
      // Message::Dm(MessageKind) where MessageKind has version, action, and payload
      // Note: Rust uses snake_case for enum variants in JSON serialization
      final content = jsonEncode([
        {
          "dm": {
            "version": 1,
            "action": "send-dm",
            "payload": {
              "text_message": text
            }
          }
        },
        null
      ]);
      
      // Create rumor (kind 1) with the serialized content
      final rumor = NostrEvent.fromPartialData(
        keyPairs: session.tradeKey,
        content: content,
        kind: 1,
        tags: [],
      );

      // Wrap the rumor using the new mostroWrap method (creates SEAL + Gift Wrap)
      final wrappedEvent = await rumor.mostroWrap(
        session.tradeKey,
        dispute.adminPubkey!,
      );

      logger.i('Sending gift wrap from ${session.tradeKey.public} to ${dispute.adminPubkey}');

      // Publish to network - await to catch network/initialization errors
      try {
        await ref.read(nostrServiceProvider).publishEvent(wrappedEvent);
        logger.i('Dispute message sent successfully to admin for dispute: $disputeId');
      } catch (publishError, publishStack) {
        logger.e('Failed to publish dispute message: $publishError', stackTrace: publishStack);
        
        // Mark message as failed
        final failedMessage = pendingMessage.copyWith(
          isPending: false,
          error: 'Failed to publish: $publishError',
        );
        final updatedMessages = state.messages.map((m) => m.id == rumorId ? failedMessage : m).toList();
        state = state.copyWith(
          messages: updatedMessages,
          error: 'Failed to send message: $publishError',
        );
        
        // Store failed state
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
        return; // Exit early, don't mark as success
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
      
      // Mark message as failed in state
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

      // Store failed state in local storage
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
      logger.i('Looking for session for dispute: $disputeId, available sessions: ${sessions.length}');
      
      // Search through all sessions to find the one that has this dispute
      for (final session in sessions) {
        if (session.orderId != null) {
          try {
            final orderState = ref.read(orderNotifierProvider(session.orderId!));
            
            // Check if this order state contains our dispute
            if (orderState.dispute?.disputeId == disputeId) {
              logger.i('Found session for dispute: $disputeId with orderId: ${session.orderId}');
              return session;
            }
          } catch (e) {
            // Continue checking other sessions
            continue;
          }
        }
      }
      
      logger.w('No session found for dispute: $disputeId');
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
    notifier.initialize();
    return notifier;
  },
);