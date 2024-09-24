import 'package:dart_nostr/dart_nostr.dart';
import 'package:mostro_mobile/core/utils/nostr_utils.dart';

class NostrService {
  static final NostrService _instance = NostrService._internal();
  factory NostrService() => _instance;
  NostrService._internal();

  late Nostr _nostr;
  KeyPair? _keyPair;

  final List<String> _relays = [
    'ws://localhost:7000',
  ];

  Future<void> init() async {
    _nostr = Nostr();
    try {
      await _nostr.relaysService.init(
        relaysUrl: _relays,
      );
      print('Nostr initialized successfully');
    } catch (e) {
      print('Failed to initialize Nostr: $e');
    }
  }

  void setPrivateKey(String privateKey) {
    try {
      _keyPair =
          _nostr.keysService.generateKeyPairFromExistingPrivateKey(privateKey);
      print('Private key set successfully');
    } catch (e) {
      print('Failed to set private key: $e');
    }
  }

  Future<void> publishEvent(int kind, String content,
      {List<List<String>>? tags}) async {
    if (_keyPair == null) {
      throw Exception('Private key not set');
    }

    try {
      final event = NostrEvent.fromPartialData(
        kind: kind,
        content: content,
        keyPairs: _keyPair!,
        tags: tags ?? [],
      );

      await _nostr.relaysService.sendEventToRelays(event);
      print('Event published: ${event.id}');
    } catch (e) {
      print('Failed to publish event: $e');
    }
  }

  Stream<NostrEvent> subscribeToEvents(NostrFilter filter) {
    final request = NostrRequest(filters: [filter]);
    return _nostr.relaysService
        .startEventsSubscription(request: request)
        .stream;
  }

  Future<void> disconnect() async {
    await _nostr.relaysService.disconnectFromRelays();
    print('Disconnected from all relays');
  }

  KeyPair generateKeyPair() {
    return NostrUtils.generateKeyPair();
  }

  String generatePrivateKey() {
    return NostrUtils.generatePrivateKey();
  }
}
