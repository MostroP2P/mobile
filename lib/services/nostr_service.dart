import 'package:collection/collection.dart';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:dart_nostr/nostr/model/relay_informations.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/data/repositories/event_storage.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/shared/providers/mostro_database_provider.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

class NostrService {
  late Settings settings;
  final Nostr _nostr = Nostr.instance;

  NostrService();

  final Logger _logger = Logger();
  bool _isInitialized = false;

  Future<void> init(Settings settings) async {
    this.settings = settings;
    try {
      await _nostr.services.relays.init(
        relaysUrl: settings.relays,
        connectionTimeout: Config.nostrConnectionTimeout,
        shouldReconnectToRelayOnNotice: true,
        retryOnClose: true,
        retryOnError: true,
        onRelayListening: (relay, url, channel) {
          _logger.i('Connected to relay: $relay');
        },
        onRelayConnectionError: (relay, error, channel) {
          _logger.w('Failed to connect to relay $relay: $error');
        },
        onRelayConnectionDone: (relay, socket) {
          _logger.i('Connection to relay: $relay via $socket is done');
        },
      );
      _isInitialized = true;
      _logger.i('Nostr initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize Nostr: $e');
      rethrow;
    }
  }

  Future<void> updateSettings(Settings newSettings) async {
    final relays = Nostr.instance.services.relays.relaysList;
    if (!ListEquality().equals(relays, newSettings.relays)) {
      _logger.i('Updating relays...');
      await init(newSettings);
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

    try {
      await _nostr.services.relays.sendEventToRelaysAsync(
        event,
        timeout: Config.nostrConnectionTimeout,
      );
      _logger.i('Event published successfully');
    } catch (e) {
      _logger.w('Failed to publish event: $e');
      rethrow;
    }
  }

  Future<List<NostrEvent>> fecthEvents(NostrFilter filter) async {
    if (!_isInitialized) {
      throw Exception('Nostr is not initialized. Call init() first.');
    }

    final request = NostrRequest(filters: [filter]);
    return await _nostr.services.relays.startEventsSubscriptionAsync(
      request: request,
      timeout: Config.nostrConnectionTimeout,
    );
  }

  Stream<NostrEvent> subscribeToEvents(NostrFilter filter) {
    if (!_isInitialized) {
      throw Exception('Nostr is not initialized. Call init() first.');
    }

    final request = NostrRequest(filters: [filter]);
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

// Add method to sync background events
  Future<void> syncBackgroundEvents() async {
    // Get the background database
    final backgroundDb = await openMostroDatabase('background.db');
    final backgroundStorage = EventStorage(db: backgroundDb);

    // Get all events from background database
    final events = await backgroundStorage.getAllItems();

    // Process each event
    for (final event in events) {
      // Process event through your regular pipeline
      // This might involve decrypting, parsing, and emitting to event bus
      await processEvent(event);
    }

    // Optionally clear background database after syncing
    // await backgroundStorage.deleteAllItems();
  }

// Add method to process events (similar to what was in MostroService)
  Future<void> processEvent(NostrEvent event) async {
    // Your event processing logic here
    // This would be similar to what was in MostroService._handleIncomingEvent
    // but without the duplicate checking
  }
}
