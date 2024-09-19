import 'package:dart_nostr/dart_nostr.dart';

class NostrService {
  static final NostrService _instance = NostrService._internal();

  factory NostrService() {
    return _instance;
  }

  NostrService._internal();

  String? _privateKey;
  final List<String> _relays = [
    'ws://localhost:7000',
  ];

  Future<void> init() async {
    try {
      // Initialize connection to relays
      await Nostr.instance.relaysService.init(relaysUrl: _relays);
      print('Nostr initialized successfully');
    } catch (e) {
      print('Failed to initialize Nostr: $e');
    }
  }

  void setPrivateKey(String? privateKey) {
    _privateKey = privateKey;
  }

  Future<void> publishEvent(int kind, String content,
      {List<List<String>>? tags}) async {
    if (_privateKey == null) {
      throw Exception('Private key not set');
    }

    // Create an event and publish it
    // final event = NostrEvent.fromPartialData(
    //   kind: kind,
    //   content: content,
    //   keyPair: KeyPair.fromPrivateKey(
    //       _privateKey!), // Assuming KeyPair handling is required
    //   tags: tags ?? [],
    // );

    // try {
    //   await Nostr.instance.relaysService.sendEventToRelays(event);
    //   print('Event published: ${event.id}');
    // } catch (e) {
    //   print('Failed to publish event: $e');
    // }
  }

  Stream<NostrEvent> subscribeToEvents(NostrFilter filter) {
    final request = NostrRequest(filters: [filter]);
    return Nostr.instance.relaysService
        .startEventsSubscription(
          request: request,
        )
        .stream;
  }

  Future<void> disconnect() async {
    await Nostr.instance.relaysService.disconnectFromRelays();
    print('Disconnected from all relays');
  }
}
