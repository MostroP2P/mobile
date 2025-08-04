import 'package:collection/collection.dart';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:dart_nostr/nostr/model/ease.dart';
import 'package:dart_nostr/nostr/model/ok.dart';
import 'package:dart_nostr/nostr/model/relay_informations.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/services/deep_link_service.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

class NostrService {
  Settings? _settings;
  final Nostr _nostr = Nostr.instance;
  final Logger _logger = Logger();
  bool _isInitialized = false;

  NostrService();
  
  /// Safe getter for settings with fallback
  Settings get settings => _settings ?? Settings(
    relays: [],
    fullPrivacyMode: false,
    mostroPublicKey: '',
  );

  Future<void> init(Settings settings) async {
    // Validate settings before initialization
    if (settings.relays.isEmpty) {
      throw Exception('Cannot initialize NostrService: No relays provided');
    }
    
    _logger.i('Initializing NostrService with relays: ${settings.relays}');
    _settings = settings;
    
    try {
      await _nostr.services.relays.init(
        relaysUrl: settings.relays,
        connectionTimeout: Config.nostrConnectionTimeout,
        shouldReconnectToRelayOnNotice: true,
        retryOnClose: true,
        retryOnError: true,
        onRelayListening: (relayUrl, receivedData, channel) {
          if (receivedData is NostrEvent) {
            _logger.d('Event from $relayUrl: ${receivedData.id}');
          } else if (receivedData is NostrNotice) {
            _logger.i('Notice from $relayUrl: ${receivedData.message}');
          } else if (receivedData is NostrEventOkCommand) {
            _logger.d('OK from $relayUrl: ${receivedData.eventId} (accepted: ${receivedData.isEventAccepted})');
          } else if (receivedData is NostrRequestEoseCommand) {
            _logger.d('EOSE from $relayUrl for subscription: ${receivedData.subscriptionId}');
          } else if (receivedData is NostrCountResponse) {
            _logger.d('Count from $relayUrl: ${receivedData.count}');
          }
        },
        onRelayConnectionError: (relay, error, channel) {
          _logger.w('Failed to connect to relay $relay: $error');
        },
        onRelayConnectionDone: (relay, socket) {
          _logger.i('Successfully connected to relay: $relay');
        },
      );
      
      _isInitialized = true;
      _logger.i('NostrService initialized successfully with ${settings.relays.length} relays');
    } catch (e) {
      _isInitialized = false;
      _logger.e('Failed to initialize NostrService: $e');
      rethrow;
    }
  }

  Future<void> updateSettings(Settings newSettings) async {
    // Compare with current settings instead of relying on dart_nostr internal state
    if (!ListEquality().equals(settings.relays, newSettings.relays)) {
      _logger.i('Updating relays from ${settings.relays} to ${newSettings.relays}');
      
      // Validate that new relay list is not empty
      if (newSettings.relays.isEmpty) {
        _logger.w('Warning: Attempting to update with empty relay list');
        return;
      }
      
      try {
        // Set initialization flag to false during update to prevent race conditions
        _isInitialized = false;
        
        // Disconnect from current relays first
        await _nostr.services.relays.disconnectFromRelays();
        _logger.i('Disconnected from previous relays');
        
        // Initialize with new relay list
        await init(newSettings);
        _logger.i('Successfully updated to new relays: ${newSettings.relays}');
      } catch (e) {
        _logger.e('Failed to update relays: $e');
        // Try to restore previous state if update fails
        try {
          await init(settings);
          _logger.i('Restored previous relay configuration');
        } catch (restoreError) {
          _logger.e('Failed to restore previous relay configuration: $restoreError');
          rethrow;
        }
      }
    } else {
      _logger.d('Relay list unchanged, skipping update');
    }
  }

  Future<RelayInformations?> getRelayInfo(String relayUrl) async {
    return await Nostr.instance.services.relays.relayInformationsDocumentNip11(
      relayUrl: relayUrl,
    );
  }

  Future<void> publishEvent(NostrEvent event) async {
    if (!_isInitialized) {
      throw Exception('Nostr is not initialized. Call init() first.');
    }

    // Defensive check: ensure relay list is not empty
    if (settings.relays.isEmpty) {
      throw Exception('Cannot publish event: No relays configured. Please add at least one relay.');
    }

    try {
      _logger.i('Publishing event ${event.id} to relays: ${settings.relays}');
      
      await _nostr.services.relays.sendEventToRelaysAsync(
        event,
        timeout: Config.nostrConnectionTimeout,
      );
      
      _logger.i('Successfully published event ${event.id}');
    } catch (e) {
      _logger.w('Failed to publish event ${event.id}: $e');
      
      // If it's the empty relay list assertion error, provide better context
      if (e.toString().contains('relaysUrl.isNotEmpty')) {
        throw Exception('Cannot publish event: Relay list is empty or not properly initialized. Current relays: ${settings.relays}');
      }
      
      rethrow;
    }
  }

  Future<List<NostrEvent>> fetchEvents(NostrFilter filter, {List<String>? specificRelays}) async {
    if (!_isInitialized) {
      throw Exception('Nostr is not initialized. Call init() first.');
    }

    // If specific relays are provided, use the relay-specific fetching logic
    if (specificRelays != null && specificRelays.isNotEmpty) {
      return await _fetchFromSpecificRelays(filter, specificRelays);
    }

    // Default behavior: use all configured relays
    final request = NostrRequest(filters: [filter]);
    return await _nostr.services.relays.startEventsSubscriptionAsync(
      request: request,
      timeout: Config.nostrConnectionTimeout,
    );
  }

  Stream<NostrEvent> subscribeToEvents(NostrRequest request) {
    if (!_isInitialized) {
      throw Exception('Nostr is not initialized. Call init() first.');
    }

    final subscription =
        _nostr.services.relays.startEventsSubscription(request: request);

    return subscription.stream;
  }

  Future<void> disconnectFromRelays() async {
    if (!_isInitialized) return;

    await _nostr.services.relays.disconnectFromRelays();
    _isInitialized = false;
    _logger.i('Disconnected from all relays');
  }

  bool get isInitialized => _isInitialized;

  Future<NostrKeyPairs> generateKeyPair() async {
    final keyPair = NostrUtils.generateKeyPair();
    return keyPair;
  }

  NostrKeyPairs generateKeyPairFromPrivateKey(String privateKey) {
    return NostrUtils.generateKeyPairFromPrivateKey(privateKey);
  }

  String getMostroPubKey() {
    return settings.mostroPublicKey;
  }

  Future<NostrEvent> createNIP59Event(
      String content, String recipientPubKey, String senderPrivateKey) async {
    if (!_isInitialized) {
      throw Exception('Nostr is not initialized. Call init() first.');
    }

    return NostrUtils.createNIP59Event(
      content,
      recipientPubKey,
      senderPrivateKey,
    );
  }

  Future<NostrEvent> decryptNIP59Event(
      NostrEvent event, String privateKey) async {
    if (!_isInitialized) {
      throw Exception('Nostr is not initialized. Call init() first.');
    }

    return NostrUtils.decryptNIP59Event(
      event,
      privateKey,
    );
  }

  Future<String> createRumor(NostrKeyPairs senderKeyPair, String wrapperKey,
      String recipientPubKey, String content) async {
    return NostrUtils.createRumor(
      senderKeyPair,
      wrapperKey,
      recipientPubKey,
      content,
    );
  }

  Future<String> createSeal(NostrKeyPairs senderKeyPair, String wrapperKey,
      String recipientPubKey, String encryptedContent) async {
    return NostrUtils.createSeal(
      senderKeyPair,
      wrapperKey,
      recipientPubKey,
      encryptedContent,
    );
  }

  Future<NostrEvent> createWrap(NostrKeyPairs wrapperKeyPair,
      String sealedContent, String recipientPubKey) async {
    return NostrUtils.createWrap(
      wrapperKeyPair,
      sealedContent,
      recipientPubKey,
    );
  }

  void unsubscribe(String id) {
    if (!_isInitialized) {
      throw Exception('Nostr is not initialized. Call init() first.');
    }

    _nostr.services.relays.closeEventsSubscription(id);
  }

  /// Fetches an event by its ID from specified relays or default relays
  /// Returns an Order if the event is a valid NIP-69 order, null otherwise
  Future<Order?> fetchEventById(String eventId,
      [List<String>? specificRelays]) async {
    if (!_isInitialized) {
      throw Exception('Nostr is not initialized. Call init() first.');
    }

    try {
      _logger.i('Fetching event with ID: $eventId');

      // Create filter to fetch the specific event
      final filter = NostrFilter(
        ids: [eventId],
        kinds: [38383], // NIP-69 order events
      );

      List<NostrEvent> events;

      if (specificRelays != null && specificRelays.isNotEmpty) {
        // Temporarily connect to specific relays for fetching
        events = await _fetchFromSpecificRelays(filter, specificRelays);
      } else {
        // Use default relays
        events = await fetchEvents(filter);
      }

      if (events.isEmpty) {
        _logger.w('No event found with ID: $eventId');
        return null;
      }

      // Find the event with the exact ID
      final event = events.firstWhere(
        (e) => e.id == eventId,
        orElse: () => throw StateError('Event not found'),
      );

      // Validate it's a proper order event
      if (event.kind != 38383) {
        _logger.w('Event $eventId is not an order event (kind: ${event.kind})');
        return null;
      }

      // Check if it's from a valid Mostro instance
      if (event.pubkey != settings.mostroPublicKey) {
        _logger.w('Event $eventId is not from the configured Mostro instance');
        return null;
      }

      _logger.i('Successfully found order event: ${event.id}');
      return Order.fromEvent(event);
    } catch (e) {
      _logger.e('Error fetching event by ID: $e');
      return null;
    }
  }

  /// Fetches order information from an event by extracting the 'd' tag (order ID) and 'k' tag (order type)
  /// This is specifically for deep link handling where the mostro: URL provides order information
  Future<OrderInfo?> fetchOrderInfoByEventId(String eventId,
      [List<String>? specificRelays]) async {
    try {
      _logger.i('Fetching order ID from event: $eventId');

      final filter = NostrFilter(
        ids: [eventId],
        kinds: [38383], // NIP-69 order events
      );

      List<NostrEvent> events;

      if (specificRelays != null && specificRelays.isNotEmpty) {
        // Temporarily connect to specific relays for fetching
        events = await _fetchFromSpecificRelays(filter, specificRelays);
      } else {
        // Use default relays
        events = await fetchEvents(filter);
      }

      if (events.isEmpty) {
        _logger.w('No event found with ID: $eventId');
        return null;
      }

      // Find the event with the exact ID
      final event = events.firstWhere(
        (e) => e.id == eventId,
        orElse: () => throw StateError('Event not found'),
      );

      // Validate it's a proper order event
      if (event.kind != 38383) {
        _logger.w('Event $eventId is not an order event (kind: ${event.kind})');
        return null;
      }

      // Check if it's from a valid Mostro instance
      if (event.pubkey != settings.mostroPublicKey) {
        _logger.w('Event $eventId is not from the configured Mostro instance');
        return null;
      }

      // Extract the order ID from the 'd' tag
      final dTag = event.tags
          ?.where((tag) => tag.isNotEmpty && tag[0] == 'd')
          .map((tag) => tag.length > 1 ? tag[1] : null)
          .where((value) => value != null)
          .cast<String>()
          .firstOrNull;

      if (dTag == null || dTag.isEmpty) {
        _logger.w('Event $eventId does not contain a valid d tag');
        return null;
      }

      // Extract the order type from the 'k' tag
      final kTag = event.tags
          ?.where((tag) => tag.isNotEmpty && tag[0] == 'k')
          .map((tag) => tag.length > 1 ? tag[1] : null)
          .where((value) => value != null)
          .cast<String>()
          .firstOrNull;

      if (kTag == null || kTag.isEmpty) {
        _logger.w('Event $eventId does not contain a valid k tag (order type)');
        return null;
      }

      OrderType orderType;
      try {
        orderType = OrderType.fromString(kTag);
      } catch (e) {
        _logger.w('Event $eventId contains invalid order type: $kTag');
        return null;
      }

      _logger.i(
          'Successfully extracted order info - ID: $dTag, Type: ${orderType.value} from event: $eventId');
      return OrderInfo(orderId: dTag, orderType: orderType);
    } catch (e) {
      _logger.e('Error fetching order ID from event: $e');
      return null;
    }
  }

  /// Fetches events from specific relays temporarily
  Future<List<NostrEvent>> _fetchFromSpecificRelays(
    NostrFilter filter,
    List<String> relays,
  ) async {
    try {
      // Store current relays
      final originalRelays = List<String>.from(settings.relays);

      // Temporarily add specific relays if not already present
      final allRelays = <String>{...originalRelays, ...relays}.toList();

      if (!ListEquality().equals(originalRelays, allRelays)) {
        _logger.i('Temporarily connecting to additional relays: $relays');

        // Update settings with additional relays
        final tempSettings = Settings(
          relays: allRelays,
          mostroPublicKey: settings.mostroPublicKey,
          fullPrivacyMode: settings.fullPrivacyMode,
          defaultFiatCode: settings.defaultFiatCode,
          selectedLanguage: settings.selectedLanguage,
        );

        await updateSettings(tempSettings);

        // Fetch the events
        final events = await fetchEvents(filter);

        // Restore original relays
        await updateSettings(settings);

        return events;
      } else {
        // No new relays to add, use normal fetch
        return await fetchEvents(filter);
      }
    } catch (e) {
      _logger.e('Error fetching from specific relays: $e');
      // Ensure we restore original settings even on error
      try {
        await updateSettings(settings);
      } catch (restoreError) {
        _logger.e('Failed to restore original relay settings: $restoreError');
      }
      rethrow;
    }
  }
}
