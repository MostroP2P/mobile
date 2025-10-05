import 'dart:async';
import 'dart:convert';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
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
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';
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
  final _logger = Logger();
  
  StreamSubscription<NostrEvent>? _subscription;
  ProviderSubscription<Session?>? _sessionListener;
  bool _isInitialized = false;

  DisputeChatNotifier(this.disputeId, this.ref) : super(const DisputeChatState());

  /// Initialize the dispute chat by loading historical messages and subscribing to new events
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _logger.i('Initializing dispute chat for disputeId: $disputeId');
    await _loadHistoricalMessages();
    _subscribe();
    _isInitialized = true;
  }

  /// Subscribe to new dispute chat messages
  void _subscribe() {
    final session = _getSessionForDispute();
    if (session == null) {
      _logger.w('No session found for dispute: $disputeId');
      _listenForSession();
      return;
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
    _logger.i('Subscribed to kind 1059 (Gift Wrap) for dispute: $disputeId');
  }

  /// Listen for session changes and subscribe when session is ready
  void _listenForSession() {
    _sessionListener?.close();
    
    final session = _getSessionForDispute();
    if (session == null) {
      _logger.w('Cannot listen for session: no session found for dispute $disputeId');
      return;
    }

    _logger.i('Starting to listen for session changes for dispute: $disputeId');

    _sessionListener = ref.listen<Session?>(
      sessionProvider(session.orderId!),
      (previous, next) {
        if (next != null) {
          _sessionListener?.close();
          _sessionListener = null;
          _logger.i('Session is now available, subscribing to kind 14 for dispute: $disputeId');
          
          _subscribe();
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
      if (dispute == null || dispute.adminPubkey == null) {
        return;
      }
      
      // Derive shared key with admin
      final adminSharedKey = NostrUtils.computeSharedKey(
        session.tradeKey.private,
        dispute.adminPubkey!,
      );
      
      // Unwrap the gift wrap using adminSharedKey
      final unwrappedEvent = await event.mostroUnWrap(adminSharedKey);

      // Parse the Mostro message from the rumor content
      String messageText = '';
      String? senderPubkey;
      bool isFromAdmin = false;
      
      try {
        // Content should be in format: [{"order": {...}}, null]
        final contentData = jsonDecode(unwrappedEvent.content ?? '[]');
        if (contentData is List && contentData.isNotEmpty) {
          final messageData = contentData[0];
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
              // Check if from admin by comparing with our tradeKey
              isFromAdmin = senderPubkey != session.tradeKey.public;
            }
          }
        }
      } catch (e) {
        _logger.w('Failed to parse Mostro message: $e');
        return;
      }

      if (messageText.isEmpty) {
        _logger.w('Received empty message, skipping');
        return;
      }

      // Store the event
      final eventStore = ref.read(eventStorageProvider);
      await eventStore.putItem(
        unwrappedEvent.id!,
        {
          'id': unwrappedEvent.id,
          'content': messageText,
          'created_at': unwrappedEvent.createdAt!.millisecondsSinceEpoch ~/ 1000,
          'kind': unwrappedEvent.kind,
          'pubkey': senderPubkey,
          'sig': unwrappedEvent.sig,
          'tags': unwrappedEvent.tags,
          'type': 'dispute_chat',
          'dispute_id': disputeId,
          'is_from_user': !isFromAdmin,
        },
      );

      // Add to state
      final disputeChat = DisputeChat(
        id: unwrappedEvent.id!,
        message: messageText,
        timestamp: unwrappedEvent.createdAt!,
        isFromUser: !isFromAdmin,
        adminPubkey: isFromAdmin ? senderPubkey : null,
      );

      final allMessages = [...state.messages, disputeChat];
      final deduped = {for (var m in allMessages) m.id: m}.values.toList();
      deduped.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      state = state.copyWith(messages: deduped);
      _logger.i('Added dispute chat message for dispute: $disputeId (from ${isFromAdmin ? "admin" : "user"})');
    } catch (e, stackTrace) {
      _logger.e('Error processing dispute chat event: $e', stackTrace: stackTrace);
    }
  }

  /// Load historical messages from storage
  Future<void> _loadHistoricalMessages() async {
    try {
      _logger.i('Loading historical messages for dispute: $disputeId');
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

      _logger.i('Found ${chatEvents.length} historical messages for dispute: $disputeId');

      final List<DisputeChat> messages = [];
      for (final eventData in chatEvents) {
        try {
          messages.add(DisputeChat(
            id: eventData['id'] as String,
            message: eventData['content'] as String? ?? '',
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              (eventData['created_at'] as int) * 1000,
            ),
            isFromUser: eventData['is_from_user'] as bool? ?? true,
            adminPubkey: eventData['admin_pubkey'] as String?,
          ));
        } catch (e) {
          _logger.w('Failed to parse dispute chat message: $e');
        }
      }

      state = state.copyWith(messages: messages, isLoading: false);
    } catch (e, stackTrace) {
      _logger.e('Error loading historical messages: $e', stackTrace: stackTrace);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Send a message in the dispute chat
  /// Uses Gift Wrap (NIP-59) with MostroMessage format like mostro-cli
  Future<void> sendMessage(String text) async {
    final session = _getSessionForDispute();
    if (session == null) {
      _logger.w('Cannot send message: Session is null for dispute: $disputeId');
      return;
    }

    // Get dispute to find admin pubkey and orderId
    final dispute = await ref.read(disputeDetailsProvider(disputeId).future);
    if (dispute == null) {
      _logger.w('Cannot send message: Dispute not found');
      return;
    }
    
    if (dispute.adminPubkey == null) {
      _logger.w('Cannot send message: Admin pubkey not found for dispute');
      return;
    }
    
    // Get orderId from session
    final orderId = session.orderId;
    if (orderId == null) {
      _logger.w('Cannot send message: Session orderId is null');
      return;
    }

    try {
      _logger.i('Sending Gift Wrap DM to admin: ${dispute.adminPubkey}');
      
      // Create Mostro message with TextMessage payload
      final mostroMessage = MostroMessage<TextMessage>(
        action: Action.sendDm,
        id: orderId,
        payload: TextMessage(message: text),
      );

      // Serialize as JSON with format: [{"order": {...}}, null]
      final messageMap = {'order': mostroMessage.toJson()};
      final content = jsonEncode([messageMap, null]);
      
      // Create rumor (kind 1) with the serialized content
      final rumor = NostrEvent.fromPartialData(
        keyPairs: session.tradeKey,
        content: content,
        kind: 1,
        tags: [],
      );

      // Create gift wrap to send directly to admin
      // Encrypt rumor with NIP-44 using ephemeral key
      final rumorJson = jsonEncode(rumor.toMap());
      final ephemeralKeyPair = NostrUtils.generateKeyPair();
      
      final encryptedRumor = await NostrUtils.encryptNIP44(
        rumorJson,
        ephemeralKeyPair.private,
        dispute.adminPubkey!, // Admin's pubkey
      );

      // Create wrapper event (kind 1059) with p tag pointing to admin
      final wrappedEvent = NostrEvent.fromPartialData(
        kind: 1059,
        content: encryptedRumor,
        keyPairs: ephemeralKeyPair,
        tags: [
          ["p", dispute.adminPubkey!], // Send directly to admin
        ],
      );

      _logger.i('Sending gift wrap from ${session.tradeKey.public} to ${dispute.adminPubkey}');

      // Add to local state immediately
      final disputeChat = DisputeChat(
        id: rumor.id!,
        message: text,
        timestamp: rumor.createdAt!,
        isFromUser: true,
      );

      final allMessages = [...state.messages, disputeChat];
      final deduped = {for (var m in allMessages) m.id: m}.values.toList();
      deduped.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      state = state.copyWith(messages: deduped);

      // Publish to network
      ref.read(nostrServiceProvider).publishEvent(wrappedEvent);
      _logger.i('Dispute message sent successfully to admin for dispute: $disputeId');

      // Store in local storage
      final eventStore = ref.read(eventStorageProvider);
      await eventStore.putItem(
        rumor.id!,
        {
          'id': rumor.id,
          'content': text,
          'created_at': rumor.createdAt!.millisecondsSinceEpoch ~/ 1000,
          'kind': rumor.kind,
          'pubkey': rumor.pubkey,
          'sig': rumor.sig,
          'tags': rumor.tags,
          'type': 'dispute_chat',
          'dispute_id': disputeId,
          'is_from_user': true,
        },
      );
    } catch (e, stackTrace) {
      _logger.e('Failed to send dispute message: $e', stackTrace: stackTrace);
      // Show error to user if needed
      state = state.copyWith(error: 'Failed to send message: $e');
    }
  }

  /// Get the session for this dispute
  Session? _getSessionForDispute() {
    try {
      final sessions = ref.read(sessionNotifierProvider);
      _logger.i('Looking for session for dispute: $disputeId, available sessions: ${sessions.length}');
      
      // Search through all sessions to find the one that has this dispute
      for (final session in sessions) {
        if (session.orderId != null) {
          try {
            final orderState = ref.read(orderNotifierProvider(session.orderId!));
            
            // Check if this order state contains our dispute
            if (orderState.dispute?.disputeId == disputeId) {
              _logger.i('Found session for dispute: $disputeId with orderId: ${session.orderId}');
              return session;
            }
          } catch (e) {
            // Continue checking other sessions
            continue;
          }
        }
      }
      
      _logger.w('No session found for dispute: $disputeId');
      return null;
    } catch (e, stackTrace) {
      _logger.e('Error getting session for dispute: $e', stackTrace: stackTrace);
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