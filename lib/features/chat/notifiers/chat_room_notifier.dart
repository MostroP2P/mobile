import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/data/models/chat_room.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/services/encrypted_image_upload_service.dart';
import 'package:mostro_mobile/services/encrypted_file_upload_service.dart';
import 'package:sembast/sembast.dart';

import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/features/chat/utils/message_type_helpers.dart';

class ChatRoomNotifier extends StateNotifier<ChatRoom> {
  /// Reload the chat room by re-subscribing to events.
  void reload() {
    // Cancel the current subscription if it exists
    _subscription?.cancel();
    subscribe();
  }

  
  final String orderId;
  final Ref ref;
  StreamSubscription<NostrEvent>? _subscription;
  ProviderSubscription<Session?>? _sessionListener;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  
  /// Exposes the mounted status of the notifier
  /// Returns true if the notifier is still active and hasn't been disposed
  @override
  bool get mounted => super.mounted;

  ChatRoomNotifier(
    super.state,
    this.orderId,
    this.ref,
  );

  /// Initialize the chat room by loading historical messages and subscribing to new events
  Future<void> initialize() async {
    await _loadHistoricalMessages();
    subscribe();
    _isInitialized = true;
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

    logger.i('Starting to listen for session changes for orderId: $orderId');

    _sessionListener = ref.listen<Session?>(
      sessionProvider(orderId),
      (previous, next) {
        logger.i(
            'Session update received for orderId: $orderId, session is null: ${next == null}, sharedKey is null: ${next?.sharedKey == null}');

        if (next != null && next.sharedKey != null) {
          // Session is now ready with shared key, subscribe to chat
          _sessionListener?.close();
          _sessionListener = null;

          logger.i(
              'Session with shared key is now available, subscribing to chat for orderId: $orderId');

          // Use SubscriptionManager to create a subscription for this specific chat room
          final subscriptionManager = ref.read(subscriptionManagerProvider);
          _subscription = subscriptionManager.chat.listen(_onChatEvent);
        }
      },
    );
  }

  void _onChatEvent(NostrEvent event) async {
    try {
      if (event.kind != 1059) {
        logger.w('Ignoring non-chat event kind: ${event.kind}');
        return;
      }

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
          'order_id': orderId,
        },
      );

      final session = ref.read(sessionProvider(orderId));
      if (session == null || session.sharedKey == null) {
        logger.e('Session or shared key is null when processing chat event');
        return;
      }

      final pTag = event.tags?.firstWhere(
            (tag) => tag.isNotEmpty && tag[0] == 'p',
            orElse: () => [],
          ) ??
          [];

      if (pTag.isEmpty ||
          pTag.length < 2 ||
          pTag[1] != session.sharedKey!.public) {
        logger.w('Event not addressed to our shared key, ignoring');
        return;
      }

      final chat = await event.p2pUnwrap(session.sharedKey!);
      
      // Process special message types (e.g., encrypted images)
      await _processMessageContent(chat);
      
      // Check if message already exists to prevent duplicates
      final messageExists = state.messages.any((m) => m.id == chat.id);
      if (!messageExists) {
        // Add new message and sort
        final updatedMessages = [...state.messages, chat];
        updatedMessages.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
        state = state.copy(messages: updatedMessages);
        logger.d('New message added from relay, total messages: ${updatedMessages.length}');
      } else {
        logger.d('Message already exists in state, skipping duplicate');
      }

      // Notify the chat rooms list to update when new messages arrive
      try {
        ref.read(chatRoomsNotifierProvider.notifier).refreshChatList();
      } catch (e) {
        logger.w('Could not refresh chat list: $e');
      }
    } catch (e, stackTrace) {
      logger.e('Error processing chat event: $e', stackTrace: stackTrace);
    }
  }

  Future<void> sendMessage(String text) async {
    final session = ref.read(sessionProvider(orderId));
    if (session == null) {
      logger.w('Cannot send message: Session is null for orderId: $orderId');
      return;
    }
    if (session.sharedKey == null) {
      logger
          .w('Cannot send message: Shared key is null for orderId: $orderId');
      return;
    }

    final innerEvent = NostrEvent.fromPartialData(
      keyPairs: session.tradeKey,
      content: text,
      kind: 1,
      tags: [
        ["p", session.sharedKey!.public],
      ],
    );

    try {
      final wrappedEvent = await innerEvent.p2pWrap(
        session.tradeKey,
        session.sharedKey!.public,
      );

      // Publish to network first - await to catch network/initialization errors
      try {
        await ref.read(nostrServiceProvider).publishEvent(wrappedEvent);
        logger.d('Message sent successfully to network');
        
        // Add the inner event to state immediately for optimistic UI
        // The relay will echo it back and _onChatEvent will handle deduplication
        final messageExists = state.messages.any((m) => m.id == innerEvent.id);
        if (!messageExists) {
          final updatedMessages = [...state.messages, innerEvent];
          updatedMessages.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
          state = state.copy(messages: updatedMessages);
          logger.d('Message added to state optimistically, total messages: ${updatedMessages.length}');
        } else {
          logger.d('Message already exists in state, skipping add');
        }
        
      } catch (publishError, publishStack) {
        logger.e('Failed to publish message: $publishError', stackTrace: publishStack);
        rethrow; // Re-throw to be caught by outer catch
      }

      // Notify the chat rooms list to update after successful publish
      try {
        ref.read(chatRoomsNotifierProvider.notifier).refreshChatList();
      } catch (e) {
        logger.w('Could not refresh chat list after sending message: $e');
      }
    } catch (e, stackTrace) {
      logger.e('Failed to send message: $e', stackTrace: stackTrace);
    }
  }

  /// Load historical chat messages from storage
  Future<void> _loadHistoricalMessages() async {
    try {
      logger.i('Starting to load historical messages for orderId: $orderId');

      final session = ref.read(sessionProvider(orderId));
      if (session == null) {
        logger.w(
            'Cannot load historical messages: session is null for orderId: $orderId');
        return;
      }
      if (session.sharedKey == null) {
        logger.w(
            'Cannot load historical messages: shared key is null for orderId: $orderId');
        return;
      }

      logger.i('Session found with shared key: ${session.sharedKey?.public}');

      final eventStore = ref.read(eventStorageProvider);

      // First, let's see how many total chat events we have
      final allChatEvents = await eventStore.find(
        filter: eventStore.eq('type', 'chat'),
      );
      logger.i('Total chat events in storage: ${allChatEvents.length}');

      // Find all chat events for this specific order
      var chatEvents = await eventStore.find(
        filter: Filter.and([
          eventStore.eq('type', 'chat'),
          eventStore.eq('order_id', orderId),
        ]),
        sort: [SortOrder('created_at', false)], // Most recent first
      );

      logger.i('Chat events found for orderId $orderId: ${chatEvents.length}');

      // Fallback: if no events found with order_id, try to find all chat events
      // This handles events stored before the order_id field was added
      if (chatEvents.isEmpty) {
        logger.i(
            'No events found with order_id, trying fallback to all chat events');
        chatEvents = await eventStore.find(
          filter: eventStore.eq('type', 'chat'),
          sort: [SortOrder('created_at', false)], // Most recent first
        );
        logger.i('Fallback: found ${chatEvents.length} total chat events');
      }

      if (chatEvents.isEmpty) {
        logger.w('No chat events found at all');
        return;
      }

      final List<NostrEvent> historicalMessages = [];

      for (int i = 0; i < chatEvents.length; i++) {
        final eventData = chatEvents[i];
        logger.i('Processing event $i: ${eventData['id']}');

        try {
          // Log the event data structure
          logger.i('Event data keys: ${eventData.keys.toList()}');

          // Check if this is a complete event (has all required fields)
          final hasCompleteData = eventData.containsKey('kind') &&
              eventData.containsKey('content') &&
              eventData.containsKey('pubkey') &&
              eventData.containsKey('sig') &&
              eventData.containsKey('tags');

          if (!hasCompleteData) {
            logger.w(
                'Event ${eventData['id']} is incomplete (missing required fields), skipping. This is likely from an older version of the app.');
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

          logger.i(
              'Reconstructed event: ${storedEvent.id}, recipient: ${storedEvent.recipient}');

          // Check if this event belongs to our chat (shared key)
          if (session.sharedKey?.public == storedEvent.recipient) {
            logger.i('Event belongs to our chat, unwrapping...');
            // Decrypt and unwrap the message
            final unwrappedMessage =
                await storedEvent.p2pUnwrap(session.sharedKey!);
            historicalMessages.add(unwrappedMessage);
            logger.i(
                'Successfully unwrapped message: ${unwrappedMessage.content}');
          } else {
            logger.i(
                'Event does not belong to our chat. Expected: ${session.sharedKey?.public}, Got: ${storedEvent.recipient}');
          }
        } catch (e) {
          logger
              .e('Failed to process historical event ${eventData['id']}: $e');
          // Continue processing other events even if one fails
        }
      }

      logger.i(
          'Total historical messages processed: ${historicalMessages.length}');

      if (historicalMessages.isNotEmpty) {
        // Merge historical messages with existing messages, avoiding duplicates
        final allMessages = [...state.messages, ...historicalMessages];
        // Deduplicate by ID
        final seen = <String>{};
        final deduped = allMessages.where((m) {
          if (seen.contains(m.id)) return false;
          seen.add(m.id!);
          return true;
        }).toList();
        deduped.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
        state = state.copy(messages: deduped);
        logger.i(
            'Successfully loaded and merged ${historicalMessages.length} historical messages, total: ${deduped.length} for chat $orderId');
      } else {
        logger.w('No historical messages loaded for chat $orderId');
        logger.i('This could be because:');
        logger.i('1. No messages have been sent in this chat yet');
        logger
            .i('2. All stored events are incomplete (from older app version)');
        logger.i(
            '3. The events belong to a different chat (shared key mismatch)');
        logger
            .i('New messages will be stored correctly and appear immediately.');
      }
    } catch (e) {
      logger.e('Error loading historical messages: $e');
      logger.e('Stack trace: ${StackTrace.current}');
    }
  }

  /// Get the shared key for this chat session (used by MessageInput)
  Future<Uint8List> getSharedKey() async {
    final session = ref.read(sessionProvider(orderId));
    if (session == null || session.sharedKey == null) {
      throw Exception('Session or shared key not available for orderId: $orderId');
    }
    
    final hexKey = session.sharedKey!.private; // This should be hex string
    
    // Validate hex key length
    if (hexKey.length != 64) {
      throw Exception('Invalid shared key length for orderId $orderId: expected 64 hex chars, got ${hexKey.length}');
    }
    
    // Convert from NostrKeyPairs to Uint8List (32 bytes)
    final sharedKeyBytes = Uint8List(32);
    
    try {
      // Convert hex string to bytes
      for (int i = 0; i < 32; i++) {
        final byte = int.parse(hexKey.substring(i * 2, i * 2 + 2), radix: 16);
        sharedKeyBytes[i] = byte;
      }
    } catch (e) {
      throw Exception('Malformed shared key for orderId $orderId: invalid hex format - $e');
    }
    
    return sharedKeyBytes;
  }

  /// Process special message content (e.g., encrypted images)
  Future<void> _processMessageContent(NostrEvent message) async {
    try {
      final content = message.content;
      if (content == null || !content.startsWith('{')) {
        // Not a JSON message, treat as regular text
        return;
      }

      // Try to parse as JSON
      Map<String, dynamic>? jsonContent;
      try {
        final decoded = jsonDecode(content);
        if (decoded is Map<String, dynamic>) {
          jsonContent = decoded;
        }
      } catch (e) {
        // Not valid JSON, treat as regular text
        return;
      }

      // Check for encrypted message types
      if (jsonContent != null) {
        if (MessageTypeUtils.isEncryptedImageMessage(message)) {
          logger.i('📸 Processing encrypted image message');
          await _processEncryptedImageMessage(message, jsonContent);
        } else if (MessageTypeUtils.isEncryptedFileMessage(message)) {
          logger.i('📎 Processing encrypted file message');
          await _processEncryptedFileMessage(message, jsonContent);
        }
      }
      
    } catch (e) {
      logger.w('Error processing message content: $e');
      // Don't rethrow - message should still be displayed as text
    }
  }

  /// Process encrypted image message by pre-downloading and caching
  Future<void> _processEncryptedImageMessage(
    NostrEvent message, 
    Map<String, dynamic> imageData
  ) async {
    try {
      // Extract image metadata
      final result = EncryptedImageUploadResult.fromJson(imageData);
      
      logger.i('📥 Pre-downloading encrypted image: ${result.filename}');
      logger.d('Blossom URL: ${result.blossomUrl}');
      logger.d('Original size: ${result.originalSize} bytes');
      
      // Get shared key for decryption
      final sharedKey = await getSharedKey();
      
      // Download and decrypt image in background
      final uploadService = EncryptedImageUploadService();
      final decryptedImage = await uploadService.downloadAndDecryptImage(
        blossomUrl: result.blossomUrl,
        sharedKey: sharedKey,
      );
      
      logger.i('✅ Image downloaded and decrypted successfully: ${decryptedImage.length} bytes');
      
      // Cache the decrypted image for immediate display
      // You could store it in a Map<String, Uint8List> for quick access
      cacheDecryptedImage(message.id!, decryptedImage, result);
      
    } catch (e) {
      logger.e('❌ Failed to process encrypted image: $e');
      // Don't rethrow - message should still be displayed (maybe with error indicator)
    }
  }

  // Simple cache for decrypted images
  final Map<String, Uint8List> _imageCache = {};
  final Map<String, EncryptedImageUploadResult> _imageMetadata = {};
  
  // Simple cache for decrypted files
  final Map<String, Uint8List> _fileCache = {};
  final Map<String, EncryptedFileUploadResult> _fileMetadata = {};

  /// Cache a decrypted image for quick display
  void cacheDecryptedImage(
    String messageId, 
    Uint8List imageData, 
    EncryptedImageUploadResult metadata
  ) {
    _imageCache[messageId] = imageData;
    _imageMetadata[messageId] = metadata;
    logger.d('🗄️ Cached decrypted image for message: $messageId');
  }

  /// Get cached decrypted image data
  Uint8List? getCachedImage(String messageId) {
    return _imageCache[messageId];
  }

  /// Get cached image metadata
  EncryptedImageUploadResult? getImageMetadata(String messageId) {
    return _imageMetadata[messageId];
  }

  /// Process encrypted file message by pre-downloading and caching
  Future<void> _processEncryptedFileMessage(
    NostrEvent message, 
    Map<String, dynamic> fileData
  ) async {
    try {
      // Extract file metadata
      final result = EncryptedFileUploadResult.fromJson(fileData);
      
      logger.i('📥 File message received: ${result.filename} (${result.fileType})');
      logger.d('Blossom URL: ${result.blossomUrl}');
      logger.d('Original size: ${result.originalSize} bytes');
      
      // Auto-download images for preview, but not other files
      if (result.fileType == 'image') {
        logger.i('📸 Auto-downloading image for preview: ${result.filename}');
        
        try {
          // Get shared key for decryption
          final sharedKey = await getSharedKey();
          
          // Download and decrypt image in background
          final uploadService = EncryptedFileUploadService();
          final decryptedFile = await uploadService.downloadAndDecryptFile(
            blossomUrl: result.blossomUrl,
            sharedKey: sharedKey,
          );
          
          logger.i('✅ Image downloaded and decrypted successfully: ${decryptedFile.length} bytes');
          
          // Cache the decrypted image for immediate display
          cacheDecryptedFile(message.id!, decryptedFile, result);
          
        } catch (e) {
          logger.e('❌ Failed to auto-download image: $e');
          // Store metadata without file data - user can manually download
          cacheDecryptedFile(message.id!, null, result);
        }
      } else {
        // Don't pre-download non-image files - let user choose when to download
        // Just store the metadata for display
        cacheDecryptedFile(message.id!, null, result);
      }
      
    } catch (e) {
      logger.e('❌ Failed to process encrypted file: $e');
      // Don't rethrow - message should still be displayed (maybe with error indicator)
    }
  }

  /// Cache a decrypted file for quick display
  void cacheDecryptedFile(
    String messageId, 
    Uint8List? fileData, 
    EncryptedFileUploadResult metadata
  ) {
    if (fileData != null) {
      _fileCache[messageId] = fileData;
    }
    _fileMetadata[messageId] = metadata;
    logger.d('🗄️ Cached file metadata for message: $messageId');
  }

  /// Get cached decrypted file data
  Uint8List? getCachedFile(String messageId) {
    return _fileCache[messageId];
  }

  /// Get cached file metadata
  EncryptedFileUploadResult? getFileMetadata(String messageId) {
    return _fileMetadata[messageId];
  }


  @override
  void dispose() {
    _subscription?.cancel();
    _sessionListener?.close();
    logger.i('Disposed chat room notifier for orderId: $orderId');
    super.dispose();
  }
}
