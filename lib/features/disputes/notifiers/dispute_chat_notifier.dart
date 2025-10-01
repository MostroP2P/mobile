import 'dart:async';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/dispute_chat.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/disputes/providers/dispute_providers.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager_provider.dart';
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
    if (session.sharedKey == null) {
      _logger.w('Session found but shared key is null for dispute: $disputeId');
      _listenForSession();
      return;
    }

    // Use SubscriptionManager to listen to chat events
    final subscriptionManager = ref.read(subscriptionManagerProvider);
    _subscription = subscriptionManager.chat.listen(_onChatEvent);
    _logger.i('Subscribed to chat events for dispute: $disputeId');
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
        if (next != null && next.sharedKey != null) {
          _sessionListener?.close();
          _sessionListener = null;
          _logger.i('Session with shared key is now available, subscribing to chat for dispute: $disputeId');
          
          final subscriptionManager = ref.read(subscriptionManagerProvider);
          _subscription = subscriptionManager.chat.listen(_onChatEvent);
        }
      },
    );
  }

  /// Handle incoming chat events
  void _onChatEvent(NostrEvent event) async {
    try {
      if (event.kind != 1059) {
        return;
      }

      final session = _getSessionForDispute();
      if (session == null || session.sharedKey == null) {
        return;
      }

      // Unwrap the event
      final unwrappedEvent = await event.mostroUnWrap(session.sharedKey!);
      
      // Check if this message belongs to this dispute
      // We need to check if the message is from/to the admin pubkey
      final dispute = await ref.read(disputeDetailsProvider(disputeId).future);
      if (dispute == null || dispute.adminPubkey == null) {
        return;
      }

      // Check if message is from admin or to admin
      final isFromAdmin = unwrappedEvent.pubkey == dispute.adminPubkey;
      final isToAdmin = unwrappedEvent.tags?.any(
          (tag) => tag.length >= 2 && tag[0] == 'p' && tag[1] == dispute.adminPubkey) ?? false;

      if (!isFromAdmin && !isToAdmin) {
        return;
      }

      // Store the event
      final eventStore = ref.read(eventStorageProvider);
      await eventStore.putItem(
        unwrappedEvent.id!,
        {
          'id': unwrappedEvent.id,
          'content': unwrappedEvent.content,
          'created_at': unwrappedEvent.createdAt!.millisecondsSinceEpoch ~/ 1000,
          'kind': unwrappedEvent.kind,
          'pubkey': unwrappedEvent.pubkey,
          'sig': unwrappedEvent.sig,
          'tags': unwrappedEvent.tags,
          'type': 'dispute_chat',
          'dispute_id': disputeId,
        },
      );

      // Add to state
      final disputeChat = DisputeChat(
        id: unwrappedEvent.id!,
        message: unwrappedEvent.content ?? '',
        timestamp: unwrappedEvent.createdAt!,
        isFromUser: !isFromAdmin,
        adminPubkey: isFromAdmin ? unwrappedEvent.pubkey : null,
      );

      final allMessages = [...state.messages, disputeChat];
      final deduped = {for (var m in allMessages) m.id: m}.values.toList();
      deduped.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      state = state.copyWith(messages: deduped);
      _logger.i('Added dispute chat message for dispute: $disputeId');
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
  Future<void> sendMessage(String text) async {
    final session = _getSessionForDispute();
    if (session == null) {
      _logger.w('Cannot send message: Session is null for dispute: $disputeId');
      return;
    }
    if (session.sharedKey == null) {
      _logger.w('Cannot send message: Shared key is null for dispute: $disputeId');
      return;
    }

    // Get dispute to find admin pubkey
    final dispute = await ref.read(disputeDetailsProvider(disputeId).future);
    if (dispute == null || dispute.adminPubkey == null) {
      _logger.w('Cannot send message: Dispute or admin pubkey not found');
      return;
    }

    final innerEvent = NostrEvent.fromPartialData(
      keyPairs: session.tradeKey,
      content: text,
      kind: 1,
      tags: [
        ["p", dispute.adminPubkey!],
      ],
    );

    try {
      final wrappedEvent = await innerEvent.mostroWrap(session.sharedKey!);

      // Add to local state immediately
      final disputeChat = DisputeChat(
        id: innerEvent.id!,
        message: text,
        timestamp: innerEvent.createdAt!,
        isFromUser: true,
      );

      final allMessages = [...state.messages, disputeChat];
      final deduped = {for (var m in allMessages) m.id: m}.values.toList();
      deduped.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      state = state.copyWith(messages: deduped);

      // Publish to network
      ref.read(nostrServiceProvider).publishEvent(wrappedEvent);
      _logger.d('Dispute message sent successfully for dispute: $disputeId');

      // Store in local storage
      final eventStore = ref.read(eventStorageProvider);
      await eventStore.putItem(
        innerEvent.id!,
        {
          'id': innerEvent.id,
          'content': innerEvent.content,
          'created_at': innerEvent.createdAt!.millisecondsSinceEpoch ~/ 1000,
          'kind': innerEvent.kind,
          'pubkey': innerEvent.pubkey,
          'sig': innerEvent.sig,
          'tags': innerEvent.tags,
          'type': 'dispute_chat',
          'dispute_id': disputeId,
          'is_from_user': true,
        },
      );
    } catch (e, stackTrace) {
      _logger.e('Failed to send dispute message: $e', stackTrace: stackTrace);
      // Remove from local state if sending failed
      final updatedMessages = state.messages.where((msg) => msg.id != innerEvent.id).toList();
      state = state.copyWith(messages: updatedMessages);
    }
  }

  /// Get the session for this dispute
  Session? _getSessionForDispute() {
    try {
      final disputeAsync = ref.read(disputeDetailsProvider(disputeId));
      return disputeAsync.when(
        data: (dispute) {
          if (dispute == null || dispute.orderId == null) return null;
          
          final sessions = ref.read(sessionNotifierProvider);
          return sessions.firstWhere(
            (s) => s.orderId == dispute.orderId,
            orElse: () => throw StateError('No session found'),
          );
        },
        loading: () => null,
        error: (_, __) => null,
      );
    } catch (e) {
      _logger.w('Error getting session for dispute: $e');
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