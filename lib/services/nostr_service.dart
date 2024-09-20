import 'package:mostro_mobile/core/utils/nostr_utils.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart'
    as nostr_event; // Usa el modelo correcto
import 'package:dart_nostr/dart_nostr.dart'; // Este es necesario para las funcionalidades de Nostr
import 'package:convert/convert.dart'; // Importar hex
import 'package:pointycastle/pointycastle.dart'; // Importar correctamente las claves

class NostrService {
  static final NostrService _instance = NostrService._internal();

  factory NostrService() {
    return _instance;
  }

  NostrService._internal();

  ECPrivateKey? _privateKey;

  final List<String> _relays = [
    'wss://localhost:7000',
  ];

  Future<void> init() async {
    try {
      await Nostr.instance.relaysService.init(relaysUrl: _relays);
      print('Nostr initialized successfully');
    } catch (e) {
      print('Failed to initialize Nostr: $e');
    }
  }

  void setPrivateKey(ECPrivateKey privateKey) {
    _privateKey = privateKey;
  }

  Future<void> publishEvent(int kind, String content,
      {List<List<String>>? tags}) async {
    if (_privateKey == null) {
      throw Exception('Private key not set');
    }

    try {
      // Crear el evento
      final keyPair = NostrUtils.generateKeyPair();
      final publicKey = keyPair.publicKey as ECPublicKey;
      final pubkeyHex = hex.encode(publicKey.Q!.getEncoded(false));

      // Aquí usamos la clase NostrEvent de tu proyecto
      final event = nostr_event.NostrEvent(
        id: '',
        kind: kind,
        pubkey: pubkeyHex,
        content: content,
        createdAt: DateTime.now(),
        tags: tags,
        sig: '',
      );

      // Generar ID y firmar el evento
      event.id = event.generateId();
      event.sig = event.signEvent(_privateKey!);

      // Enviar el evento a los relays
      await Nostr.instance.relaysService.sendEventToRelays(event as NostrEvent);

      print('Event published: ${event.id}');
    } catch (e) {
      print('Failed to publish event: $e');
    }
  }

  Stream<NostrEvent> subscribeToEvents(NostrFilter filter) {
    final request = NostrRequest(filters: [filter]);

    return Nostr.instance.relaysService
        .startEventsSubscription(request: request)
        .stream;
  }

  Future<void> disconnect() async {
    await Nostr.instance.relaysService.disconnectFromRelays();
    print('Disconnected from all relays');
  }
}
