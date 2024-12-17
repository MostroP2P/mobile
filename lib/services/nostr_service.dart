import 'package:dart_nostr/dart_nostr.dart';
import 'package:mostro_mobile/app/config.dart';
import 'package:logging/logging.dart';
import 'package:mostro_mobile/shared/utils/auth_utils.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

class NostrService {
  static final NostrService _instance = NostrService._internal();
  factory NostrService() => _instance;
  NostrService._internal();

  final Logger _logger = Logger('NostrService');
  late Nostr _nostr;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    _nostr = Nostr.instance;
    try {
      await _nostr.relaysService.init(
        relaysUrl: Config.nostrRelays,
        connectionTimeout: Config.nostrConnectionTimeout,
        onRelayListening: (relay, url, 
        channel) {
          _logger.info('Connected to relay: $url');
        },
        onRelayConnectionError: (relay, error, channel) {
          _logger.warning('Failed to connect to relay $relay: $error');
        },
      );
      _isInitialized = true;
      _logger.info('Nostr initialized successfully');
    } catch (e) {
      _logger.severe('Failed to initialize Nostr: $e');
      rethrow;
    }
  }

  Future<void> publishEvent(NostrEvent event) async {
    if (!_isInitialized) {
      throw Exception('Nostr is not initialized. Call init() first.');
    }

    try {
      await _nostr.relaysService.sendEventToRelaysAsync(event,
          timeout: Config.nostrConnectionTimeout);
      _logger.info('Event published successfully');
    } catch (e) {
      _logger.warning('Failed to publish event: $e');
      rethrow;
    }
  }

  Stream<NostrEvent> subscribeToEvents(NostrFilter filter) {
    if (!_isInitialized) {
      throw Exception('Nostr is not initialized. Call init() first.');
    }

    final request = NostrRequest(filters: [filter]);
    final subscription =
        _nostr.relaysService.startEventsSubscription(request: request);

    return subscription.stream;
  }

  Future<void> disconnectFromRelays() async {
    if (!_isInitialized) return;

    await _nostr.relaysService.disconnectFromRelays();
    _isInitialized = false;
    _logger.info('Disconnected from all relays');
  }

  bool get isInitialized => _isInitialized;

  Future<NostrKeyPairs> generateKeyPair() async {
    final keyPair = NostrUtils.generateKeyPair();
    await AuthUtils.savePrivateKeyAndPin(
        keyPair.private, ''); // Consider adding a password parameter
    return keyPair;
  }

  String getMostroPubKey() {
    return Config.mostroPubKey;
  }

  Future<NostrEvent> createNIP59Event(
      String content, String recipientPubKey, String senderPrivateKey) async {
    if (!_isInitialized) {
      throw Exception('Nostr is not initialized. Call init() first.');
    }

    return NostrUtils.createNIP59Event(
        content, recipientPubKey, senderPrivateKey);
  }

  Future<NostrEvent> decryptNIP59Event(NostrEvent event, String privateKey) async {
    if (!_isInitialized) {
      throw Exception('Nostr is not initialized. Call init() first.');
    }

    return NostrUtils.decryptNIP59Event(event, privateKey);
  }
}
