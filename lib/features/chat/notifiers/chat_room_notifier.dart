import 'dart:async';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/chat_room.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:sembast/sembast.dart';

import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';

class ChatRoomNotifier extends StateNotifier<ChatRoom> {
  /// Reload the chat room by re-subscribing to events.
  void reload() {
    // Cancel the current subscription if it exists
    _subscription?.cancel();
    subscribe();
  }

  final _logger = Logger();
  final String orderId;
  final Ref ref;
  StreamSubscription<NostrEvent>? _subscription;
  ProviderSubscription<Session?>? _sessionListener;

  ChatRoomNotifier(
    super.state,
    this.orderId,
    this.ref,
  ) {
    // Load historical messages when the notifier is created
    _loadHistoricalMessages().then((_) {
      // Start listening for new messages after loading historical ones
      subscribe();
    });
  }

  void subscribe() {
    final session = ref.read(sessionProvider(orderId));
    if (session == null) {
      // Session not available yet, listen for when it becomes available
      _listenForSession();
      return;
    }
    if (session.sharedKey == null) {
      // Session exists but shared key not available yet, listen for when it becomes available
      _listenForSession();
      return;
    }

    // Use SubscriptionManager to create a subscription for this specific chat room
    final subscriptionManager = ref.read(subscriptionManagerProvider);
    _subscription = subscriptionManager.chat.listen(_onChatEvent);
  }

  /// Listen for session changes and subscribe when session is ready
  void _listenForSession() {
    // Cancel any existing listener
    _sessionListener?.close();
    
    _logger.i('Starting to listen for session changes for orderId: $orderId');
    
    _sessionListener = ref.listen<Session?>(
      sessionProvider(orderId),
      (previous, next) {
        _logger.i('Session update received for orderId: $orderId, session is null: ${next == null}, sharedKey is null: ${next?.sharedKey == null}');
        
        if (next != null && next.sharedKey != null) {
          // Session is now ready with shared key, subscribe to chat
          _sessionListener?.close();
          _sessionListener = null;
          
          _logger.i('Session with shared key is now available, subscribing to chat for orderId: $orderId');
          
          // Use SubscriptionManager to create a subscription for this specific chat room
          final subscriptionManager = ref.read(subscriptionManagerProvider);
          _subscription = subscriptionManager.chat.listen(_onChatEvent);
        }
      },
    );
  }

  void _onChatEvent(NostrEvent event) async {
    try {
      // Check if event is already processed to prevent duplicate notifications
      final eventStore = ref.read(eventStorageProvider);
      if (await eventStore.hasItem(event.id!)) {
        return;
      }
      
      // Store the complete event to prevent future duplicates and enable historical loading
      await eventStore.putItem(
        event.id!,
        {
          'id': event.id,
          'created_at': event.createdAt!.millisecondsSinceEpoch ~/ 1000,
          'kind': event.kind,
          'content': event.content,
          'pubkey': event.pubkey,
          'sig': event.sig,
          'tags': event.tags,
          'type': 'chat',
          'order_id': orderId, // Add order ID for filtering
        },
      );

      final session = ref.read(sessionProvider(orderId));
      if (session == null || session.sharedKey == null) {
        _logger.e('Session or shared key is null when processing chat event');
        return;
      }

      if (session.sharedKey?.public != event.recipient) {
        return;
      }

      final chat = await event.mostroUnWrap(session.sharedKey!);
      // Deduplicate by message ID and always sort by createdAt
      final allMessages = [
        ...state.messages,
        chat,
      ];
      // Use a map to deduplicate by event id
      final deduped = {for (var m in allMessages) m.id: m}.values.toList();

      deduped.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
      state = state.copy(messages: deduped);
      
      // Notify the chat rooms list to update when new messages arrive
      try {
        ref.read(chatRoomsNotifierProvider.notifier).refreshChatList();
      } catch (e) {
        _logger.w('Could not refresh chat list: $e');
      }
    } catch (e) {
      _logger.e(e);
    }
  }

  Future<void> sendMessage(String text) async {
    final session = ref.read(sessionProvider(orderId));
    if (session == null) {
      _logger.w('Cannot send message: Session is null for orderId: $orderId');
      return;
    }
    if (session.sharedKey == null) {
      _logger.w('Cannot send message: Shared key is null for orderId: $orderId');
      return;
    }
    
    // Create the event with current timestamp for immediate display
    final event = NostrEvent.fromPartialData(
      keyPairs: session.tradeKey,
      content: text,
      kind: 1,
    );

    // Immediately add the sent message to local state for instant UI update
    final allMessages = [
      ...state.messages,
      event,
    ];
    // Use a map to deduplicate by event id
    final deduped = {for (var m in allMessages) m.id: m}.values.toList();
    deduped.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
    state = state.copy(messages: deduped);
    
    // Notify the chat rooms list to update immediately
    try {
      ref.read(chatRoomsNotifierProvider.notifier).refreshChatList();
    } catch (e) {
      _logger.w('Could not refresh chat list after sending message: $e');
    }

    // Then send the message to the network (async)
    try {
      final wrappedEvent = await event.mostroWrap(session.sharedKey!);
      ref.read(nostrServiceProvider).publishEvent(wrappedEvent);
      _logger.d('Message sent successfully to network');
    } catch (e) {
      _logger.e('Failed to send message to network: $e');
      // TODO: Could implement retry logic or show error to user
    }
  }

  /// Load historical chat messages from storage
  Future<void> _loadHistoricalMessages() async {
    try {
      _logger.i('Starting to load historical messages for orderId: $orderId');
      
      final session = ref.read(sessionProvider(orderId));
      if (session == null) {
        _logger.w('Cannot load historical messages: session is null for orderId: $orderId');
        return;
      }
      if (session.sharedKey == null) {
        _logger.w('Cannot load historical messages: shared key is null for orderId: $orderId');
        return;
      }
      
      _logger.i('Session found with shared key: ${session.sharedKey?.public}');

      final eventStore = ref.read(eventStorageProvider);
      
      // First, let's see how many total chat events we have
      final allChatEvents = await eventStore.find(
        filter: eventStore.eq('type', 'chat'),
      );
      _logger.i('Total chat events in storage: ${allChatEvents.length}');
      
      // Find all chat events for this specific order
      var chatEvents = await eventStore.find(
        filter: Filter.and([
          eventStore.eq('type', 'chat'),
          eventStore.eq('order_id', orderId),
        ]),
        sort: [SortOrder('created_at', false)], // Most recent first
      );
      
      _logger.i('Chat events found for orderId $orderId: ${chatEvents.length}');
      
      // Fallback: if no events found with order_id, try to find all chat events
      // This handles events stored before the order_id field was added
      if (chatEvents.isEmpty) {
        _logger.i('No events found with order_id, trying fallback to all chat events');
        chatEvents = await eventStore.find(
          filter: eventStore.eq('type', 'chat'),
          sort: [SortOrder('created_at', false)], // Most recent first
        );
        _logger.i('Fallback: found ${chatEvents.length} total chat events');
      }
      
      if (chatEvents.isEmpty) {
        _logger.w('No chat events found at all');
        return;
      }

      final List<NostrEvent> historicalMessages = [];
      
      for (int i = 0; i < chatEvents.length; i++) {
        final eventData = chatEvents[i];
        _logger.i('Processing event $i: ${eventData['id']}');
        
        try {
          // Log the event data structure
          _logger.i('Event data keys: ${eventData.keys.toList()}');
          
          // Check if this is a complete event (has all required fields)
          final hasCompleteData = eventData.containsKey('kind') && 
                                 eventData.containsKey('content') && 
                                 eventData.containsKey('pubkey') && 
                                 eventData.containsKey('sig') && 
                                 eventData.containsKey('tags');
          
          if (!hasCompleteData) {
            _logger.w('Event ${eventData['id']} is incomplete (missing required fields), skipping. This is likely from an older version of the app.');
            continue;
          }
          
          // Reconstruct the NostrEvent from stored data
          final storedEvent = NostrEventExtensions.fromMap({
            'id': eventData['id'],
            'created_at': eventData['created_at'],
            'kind': eventData['kind'],
            'content': eventData['content'],
            'pubkey': eventData['pubkey'],
            'sig': eventData['sig'],
            'tags': eventData['tags'],
          });
          
          _logger.i('Reconstructed event: ${storedEvent.id}, recipient: ${storedEvent.recipient}');

          // Check if this event belongs to our chat (shared key)
          if (session.sharedKey?.public == storedEvent.recipient) {
            _logger.i('Event belongs to our chat, unwrapping...');
            // Decrypt and unwrap the message
            final unwrappedMessage = await storedEvent.mostroUnWrap(session.sharedKey!);
            historicalMessages.add(unwrappedMessage);
            _logger.i('Successfully unwrapped message: ${unwrappedMessage.content}');
          } else {
            _logger.i('Event does not belong to our chat. Expected: ${session.sharedKey?.public}, Got: ${storedEvent.recipient}');
          }
        } catch (e) {
          _logger.e('Failed to process historical event ${eventData['id']}: $e');
          // Continue processing other events even if one fails
        }
      }

      _logger.i('Total historical messages processed: ${historicalMessages.length}');

      if (historicalMessages.isNotEmpty) {
        // Update state with historical messages
        final deduped = {for (var m in historicalMessages) m.id: m}.values.toList();
        deduped.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
        state = state.copy(messages: deduped);
        _logger.i('Successfully loaded ${deduped.length} historical messages for chat $orderId');
      } else {
        _logger.w('No historical messages loaded for chat $orderId');
        _logger.i('This could be because:');
        _logger.i('1. No messages have been sent in this chat yet');
        _logger.i('2. All stored events are incomplete (from older app version)');
        _logger.i('3. The events belong to a different chat (shared key mismatch)');
        _logger.i('New messages will be stored correctly and appear immediately.');
      }
    } catch (e) {
      _logger.e('Error loading historical messages: $e');
      _logger.e('Stack trace: ${StackTrace.current}');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _sessionListener?.close();
    _logger.i('Disposed chat room notifier for orderId: $orderId');
    super.dispose();
  }
}
