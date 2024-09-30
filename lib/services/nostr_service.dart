import 'package:dart_nostr/dart_nostr.dart';
import 'package:mostro_mobile/core/config.dart';

class NostrService {
  static final NostrService _instance = NostrService._internal();
  factory NostrService() => _instance;
  NostrService._internal();

  late Nostr _nostr;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    _nostr = Nostr.instance;
    try {
      await _nostr.relaysService.init(
        relaysUrl: Config.nostrRelays,
        connectionTimeout: Config.nostrConnectionTimeout,
        onRelayListening: (relay, url, channel) {
          print('Connected to relay: $url');
        },
        onRelayConnectionError: (relay, error, channel) {
          print('Failed to connect to relay $relay: $error');
        },
      );
      _isInitialized = true;
      print('Nostr initialized successfully');
    } catch (e) {
      print('Failed to initialize Nostr: $e');
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
      print('Event published successfully');
    } catch (e) {
      print('Failed to publish event: $e');
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
  }

  bool get isInitialized => _isInitialized;

  NostrKeyPairs generateKeyPair() {
    return _nostr.keysService.generateKeyPair();
  }

  String signMessage(String message, String privateKey) {
    return _nostr.keysService.sign(privateKey: privateKey, message: message);
  }

  bool verifySignature(String signature, String message, String publicKey) {
    return _nostr.keysService
        .verify(publicKey: publicKey, message: message, signature: signature);
  }

  // Nuevo método para obtener la clave pública de Mostro
  String getMostroPubKey() {
    return Config.mostroPubKey;
  }
}
