import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/chat/providers/active_chat_screens_provider.dart';
import 'package:mostro_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/chat/utils/message_type_helpers.dart';
import 'package:mostro_mobile/services/chat_cursor_store.dart';
import 'package:mostro_mobile/services/encrypted_image_upload_service.dart';
import 'package:mostro_mobile/services/encrypted_file_upload_service.dart';
import 'package:mostro_mobile/shared/mixins/media_cache_mixin.dart';
import 'package:mostro_mobile/shared/utils/chat_keys.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';
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
/// Uses the Mostro chat kind-14 envelope (chatWrap/chatUnwrap) with keys
/// derived from the admin ECDH shared secret.
/// Stores the encrypted outer events on disk, same pattern as P2P chat.
class DisputeChatNotifier extends StateNotifier<DisputeChatState> with MediaCacheMixin {
  static final EncryptedImageUploadService _imageUploadService =
      EncryptedImageUploadService();
  static final EncryptedFileUploadService _fileUploadService =
      EncryptedFileUploadService();

  final String disputeId;
  final Ref ref;

  StreamSubscription<NostrEvent>? _subscription;
  ProviderSubscription<dynamic>? _sessionListener;
  bool _isInitialized = false;

  ChatKeys? _chatKeys;
  String? _chatKeysSource;

  DisputeChatNotifier(this.disputeId, this.ref) : super(const DisputeChatState());

  /// Derive (and cache) the K_conv/K_sign pair from the admin shared key.
  ChatKeys _getChatKeys(Session session) {
    final shared = session.adminSharedKey!;
    if (_chatKeys == null || _chatKeysSource != shared.public) {
      _chatKeys = ChatKeys.fromSharedKey(shared);
      _chatKeysSource = shared.public;
    }
    return _chatKeys!;
  }


  /// Initialize the dispute chat by loading historical messages and subscribing to new events
  Future<void> initialize() async {
    if (_isInitialized || !mounted) return;

    logger.i('Initializing dispute chat for disputeId: $disputeId');
    await _loadHistoricalMessages();
    if (!mounted) return;
    await _subscribe();
    if (!mounted) return;
    _isInitialized = true;
  }

  /// Subscribe to new dispute chat messages using admin shared key
  Future<void> _subscribe() async {
    if (!mounted) return;

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
      if (!mounted) return;
      _subscription = null;
    }

    // Subscribe to kind 14 chat events authored by K_sign. The spec requires
    // filtering by authors, not #p, to prevent third-party flooding.
    final chatKeys = _getChatKeys(session);
    final nostrService = ref.read(nostrServiceProvider);

    // Persisted per-conversation cursor (spec MUST); default lookback for
    // conversations with no accepted events yet
    final cursorSince =
        await ref.read(disputeChatCursorStoreProvider).sinceFor(disputeId);
    if (!mounted) return;
    final since = cursorSince ??
        DateTime.now().subtract(NostrEventExtensions.chatDefaultLookback);

    final request = NostrRequest(
      filters: [
        NostrFilter(
          kinds: [14],
          authors: [chatKeys.sign.public],
          since: since,
          limit: NostrEventExtensions.chatDefaultLimit,
        ),
      ],
    );

    _subscription = nostrService.subscribeToEvents(request).listen(_onChatEvent);
    logger.i('Subscribed to kind 14 chat via K_sign for dispute: $disputeId');
  }

  /// Listen for session changes and subscribe when admin shared key is ready
  void _listenForSession() {
    if (!mounted) return;

    // Cancel any previous listener to avoid leaks
    _sessionListener?.close();
    _sessionListener = null;

    logger.i('Listening for session changes (admin shared key) for dispute: $disputeId');

    // Watch the entire session list for changes
    _sessionListener = ref.listen<List<Session>>(
      sessionNotifierProvider,
      (previous, next) {
        if (!mounted) return;

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

  /// Handle incoming chat events via chatUnwrap.
  /// Stores the outer event (encrypted) to disk, then unwraps for display.
  void _onChatEvent(NostrEvent event) async {
    try {
      if (!mounted || event.kind != 14) return;

      final session = _getSessionForDispute();
      if (session == null || session.adminSharedKey == null) return;

      // Cheap pre-filter; chatUnwrap re-checks this among the spec checks
      final chatKeys = _getChatKeys(session);
      if (event.pubkey != chatKeys.sign.public) return;

      // Check for duplicate outer events (relay re-deliveries)
      final wrapperEventId = event.id;
      if (wrapperEventId == null) return;
      // Already on disk means a relay re-delivery, an own echo, or an event
      // the background service stored while the app slept. Keep processing:
      // state is keyed by inner id, so only the write is redundant.
      final eventStore = ref.read(eventStorageProvider);
      final alreadyStored = await eventStore.hasItem(wrapperEventId);

      // Unwrap and authenticate BEFORE persisting: the signature is not part
      // of the event id, so storing an unverified copy would let a corrupted
      // duplicate occupy the id and dedup away the valid one for good
      final unwrappedEvent = await event.chatUnwrap(
        chatKeys,
        session.disputeChatAllowedSigners,
      );

      // Store the outer event (encrypted) to disk — same pattern as P2P chat
      if (!alreadyStored) {
        await eventStore.putItem(
          wrapperEventId,
          event.disputeChatRecord(disputeId),
        );
      }
      if (!mounted) return;

      // Advance the persisted since cursor only after the event is accepted
      // (clamped to the local clock inside the store)
      unawaited(
        ref
            .read(disputeChatCursorStoreProvider)
            .advance(disputeId, event.createdAt!),
      );

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

      if (isFromAdmin) {
        _maybeShowInAppNotification();
      }

      // Fire-and-forget: pre-download media after message is in state
      unawaited(_processMessageContent(unwrappedEvent));
      logger.i('Added dispute chat message for dispute: $disputeId '
          '(from ${isFromAdmin ? "admin" : "user"})');
    } catch (e, stackTrace) {
      logger.e('Error processing dispute chat event: $e', stackTrace: stackTrace);
    }
  }

  /// Show an in-app snackbar for incoming admin messages when the user is not
  /// currently on this dispute chat screen. Messages the user sent themselves
  /// are filtered upstream (`isFromAdmin`).
  void _maybeShowInAppNotification() {
    try {
      if (!mounted) return;

      final activeScreens = ref.read(activeChatScreensProvider);
      if (activeScreens.contains(disputeId)) return;

      ref
          .read(notificationActionsProvider.notifier)
          .showCustomMessage('disputeChatNewMessage');
    } catch (e) {
      logger.w('Failed to show in-app dispute chat notification: $e');
    }
  }

  /// Load historical messages from storage.
  /// Reconstructs stored outer events and unwraps them: kind 14 via
  /// chatUnwrap, legacy kind 1059 (pre-migration) via p2pUnwrap.
  Future<void> _loadHistoricalMessages() async {
    try {
      if (!mounted) return;
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
      if (!mounted) return;

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

          // Reconstruct the outer NostrEvent from stored data
          final storedEvent = NostrEventExtensions.fromMap({
            'id': eventData['id'],
            'created_at': eventData['created_at'],
            'kind': eventData['kind'],
            'content': eventData['content'],
            'pubkey': eventData['pubkey'],
            'sig': eventData['sig'],
            'tags': eventData['tags'],
          });

          // Decrypt and unwrap: kind 14 envelope, or legacy gift wrap
          // stored before the kind-14 migration
          final NostrEvent unwrappedEvent;
          if (storedEvent.kind == 14) {
            unwrappedEvent = await storedEvent.chatUnwrap(
              _getChatKeys(session),
              session.disputeChatAllowedSigners,
            );
          } else {
            if (session.adminSharedKey!.public != storedEvent.recipient) {
              continue;
            }
            unwrappedEvent = await storedEvent.p2pUnwrap(session.adminSharedKey!);
          }
          if (!mounted) return;
          // Fire-and-forget: pre-download media without blocking history load
          unawaited(_processMessageContent(unwrappedEvent));
          messages.add(DisputeChatMessage(event: unwrappedEvent));
        } catch (e) {
          logger.w('Failed to process historical dispute event ${eventData['id']}: $e');
        }
      }

      // Dedup by inner event ID
      final deduped = {for (var m in messages) m.id: m}.values.toList();
      deduped.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      if (!mounted) return;
      state = state.copyWith(messages: deduped, isLoading: false);
    } catch (e, stackTrace) {
      logger.e('Error loading historical messages: $e', stackTrace: stackTrace);
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Send a message in the dispute chat using the kind-14 chat envelope.
  /// Stores the outer event (encrypted) on success.
  Future<void> sendMessage(String text) async {
    if (!mounted) return;

    final session = _getSessionForDispute();
    if (session == null) {
      logger.w('Cannot send message: Session is null for dispute: $disputeId');
      return;
    }

    if (session.adminSharedKey == null) {
      logger.w('Cannot send message: Admin shared key not available for dispute: $disputeId');
      return;
    }

    // Create the inner event (kind 1 with a `u` nonce tag) FIRST to get
    // the real event ID used for optimistic UI and echo deduplication
    final rumor = NostrEventExtensions.createChatRumor(
      senderKeys: session.tradeKey,
      content: text,
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

      // Wrap into the kind-14 envelope (signed by K_sign, encrypted with K_conv)
      final wrappedEvent = await rumor.chatWrap(_getChatKeys(session));
      if (!mounted) return;

      // Publish to network
      try {
        await ref.read(nostrServiceProvider).publishEvent(wrappedEvent);
        if (!mounted) return;
        logger.i('Dispute message sent successfully for dispute: $disputeId');
      } catch (publishError, publishStack) {
        logger.e('Failed to publish dispute message: $publishError',
            stackTrace: publishStack);
        _updateMessageState(rumorId, isPending: false, error: 'Failed to publish: $publishError');
        return;
      }

      // On success: store the outer event (encrypted) to disk
      final eventStore = ref.read(eventStorageProvider);
      await eventStore.putItem(
        wrappedEvent.id!,
        wrappedEvent.disputeChatRecord(disputeId),
      );
      if (!mounted) return;

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
    if (!mounted) return;

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
    return NostrUtils.sharedKeyToBytes(session.adminSharedKey!);
  }

  /// Process special message content (encrypted images/files) for auto-download
  Future<void> _processMessageContent(NostrEvent message) async {
    try {
      final content = message.content;
      if (content == null || !content.startsWith('{')) return;

      Map<String, dynamic>? jsonContent;
      try {
        final decoded = jsonDecode(content);
        if (decoded is Map<String, dynamic>) {
          jsonContent = decoded;
        }
      } catch (_) {
        return;
      }

      if (jsonContent != null) {
        if (MessageTypeUtils.isEncryptedImageMessage(message)) {
          await _processEncryptedImageMessage(message, jsonContent);
        } else if (MessageTypeUtils.isEncryptedFileMessage(message)) {
          await _processEncryptedFileMessage(message, jsonContent);
        }
      }
    } catch (e) {
      logger.w('Error processing message content: $e');
    }
  }

  Future<void> _processEncryptedImageMessage(NostrEvent message, Map<String, dynamic> imageData) async {
    try {
      final result = EncryptedImageUploadResult.fromJson(imageData);
      final sharedKey = await getAdminSharedKey();
      final decryptedImage = await _imageUploadService.downloadAndDecryptImage(
        blossomUrl: result.blossomUrl,
        sharedKey: sharedKey,
      );
      cacheDecryptedImage(message.id!, decryptedImage, result);
    } catch (e) {
      logger.e('Failed to process encrypted image: $e');
    }
  }

  Future<void> _processEncryptedFileMessage(NostrEvent message, Map<String, dynamic> fileData) async {
    try {
      final result = EncryptedFileUploadResult.fromJson(fileData);
      if (result.fileType == 'image') {
        try {
          final sharedKey = await getAdminSharedKey();
          final decryptedFile = await _fileUploadService.downloadAndDecryptFile(
            blossomUrl: result.blossomUrl,
            sharedKey: sharedKey,
          );
          cacheDecryptedFile(message.id!, decryptedFile, result);
        } catch (e) {
          logger.e('Failed to auto-download image file: $e');
          cacheDecryptedFile(message.id!, null, result);
        }
      } else {
        cacheDecryptedFile(message.id!, null, result);
      }
    } catch (e) {
      logger.e('Failed to process encrypted file: $e');
    }
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
    clearMediaCaches();
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
