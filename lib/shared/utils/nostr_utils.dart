import 'dart:convert';
import 'dart:math';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:elliptic/elliptic.dart';
import 'package:nip44/nip44.dart';

class NostrUtils {
  static final Nostr _instance = Nostr.instance;

  // Generación de claves
  static NostrKeyPairs generateKeyPair() {
    try {
      final privateKey = generatePrivateKey();
      if (!isValidPrivateKey(privateKey)) {
        throw Exception('Generated invalid private key');
      }
      return NostrKeyPairs(private: privateKey);
    } catch (e) {
      throw Exception('Failed to generate key pair: $e');
    }
  }

  static NostrKeyPairs generateKeyPairFromPrivateKey(String privateKey) {
    return _instance.services.keys
        .generateKeyPairFromExistingPrivateKey(privateKey);
  }

  static String generatePrivateKey() {
    try {
      return getS256().generatePrivateKey().toHex();
    } catch (e) {
      throw Exception('Failed to generate private key: $e');
    }
  }

  // Codificación y decodificación de claves
  static String encodePrivateKeyToNsec(String privateKey) {
    return _instance.services.bech32.encodePrivateKeyToNsec(privateKey);
  }

  static String decodeNsecKeyToPrivateKey(String nsec) {
    return _instance.services.bech32.decodeNsecKeyToPrivateKey(nsec);
  }

  static String encodePublicKeyToNpub(String publicKey) {
    return _instance.services.bech32.encodePublicKeyToNpub(publicKey);
  }

  static String decodeNpubKeyToPublicKey(String npub) {
    return _instance.services.bech32.decodeNpubKeyToPublicKey(npub);
  }

  static String nsecToHex(String nsec) {
    if (nsec.startsWith('nsec')) {
      return decodeNsecKeyToPrivateKey(nsec);
    }
    return nsec; // Si ya es hex, devolverlo tal cual
  }

  // Operaciones con claves
  static String derivePublicKey(String privateKey) {
    return _instance.services.keys.derivePublicKey(privateKey: privateKey);
  }

  static bool isValidPrivateKey(String privateKey) {
    return _instance.services.keys.isValidPrivateKey(privateKey);
  }

  // Firma y verificación
  static String signMessage(String message, String privateKey) {
    return _instance.services.keys
        .sign(privateKey: privateKey, message: message);
  }

  static bool verifySignature(
      String signature, String message, String publicKey) {
    return _instance.services.keys
        .verify(publicKey: publicKey, message: message, signature: signature);
  }

  // Creación de eventos
  static NostrEvent createEvent({
    required int kind,
    required String content,
    required String privateKey,
    List<List<String>> tags = const [],
    DateTime? createdAt,
  }) {
    final keyPair = generateKeyPairFromPrivateKey(privateKey);
    return NostrEvent.fromPartialData(
      kind: kind,
      content: content,
      keyPairs: keyPair,
      tags: tags,
      createdAt: createdAt,
    );
  }

  // Utilidades generales
  static String decodeBech32(String bech32String) {
    final result = _instance.services.bech32.decodeBech32(bech32String);
    return result[0]; // Devuelve la parte de datos (índice 0)
  }

  static String encodeBech32(String hrp, String data) {
    return _instance.services.bech32.encodeBech32(hrp, data);
  }

  /// Decodes a nevent string (NIP-19) to extract event ID and relay information
  /// Returns a map with 'eventId' and 'relays' keys
  static Map<String, dynamic> decodeNevent(String nevent) {
    if (!nevent.startsWith('nevent1')) {
      throw ArgumentError('Invalid nevent format: must start with nevent1');
    }

    try {
      final decoded = _instance.services.bech32.decodeBech32(nevent);
      if (decoded.isEmpty || decoded.length < 2) {
        throw FormatException('Invalid bech32 decoding result');
      }

      final data = decoded[0]; // Get the data part (index 0)
      final bytes = hex.decode(data);

      final result = <String, dynamic>{
        'eventId': '',
        'relays': <String>[],
      };

      // Parse TLV (Type-Length-Value) format
      int index = 0;
      while (index < bytes.length) {
        if (index + 2 >= bytes.length) break;

        final type = bytes[index];
        final length = bytes[index + 1];

        if (index + 2 + length > bytes.length) break;

        final value = bytes.sublist(index + 2, index + 2 + length);

        switch (type) {
          case 0: // Event ID (32 bytes)
            if (length == 32) {
              result['eventId'] = hex.encode(value);
            }
            break;
          case 1: // Relay URL (variable length)
            final relayUrl = utf8.decode(value);
            if (relayUrl.isNotEmpty) {
              (result['relays'] as List<String>).add(relayUrl);
            }
            break;
          // Skip other types for now
        }

        index += 2 + length;
      }

      if ((result['eventId'] as String).isEmpty) {
        throw FormatException('No event ID found in nevent');
      }

      return result;
    } catch (e) {
      throw FormatException('Failed to decode nevent: $e');
    }
  }

  /// Validates if a string is a valid nostr: URL
  static bool isValidNostrUrl(String url) {
    if (!url.startsWith('nostr:')) return false;

    final nevent = url.substring(6); // Remove 'nostr:' prefix

    try {
      decodeNevent(nevent);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Parses a nostr: URL and returns event information
  static Map<String, dynamic>? parseNostrUrl(String url) {
    if (!isValidNostrUrl(url)) return null;

    final nevent = url.substring(6); // Remove 'nostr:' prefix

    try {
      return decodeNevent(nevent);
    } catch (e) {
      return null;
    }
  }

  /// Validates if a string is a valid mostro: URL
  /// Format: mostro:order-id&relays=wss://relay1,wss://relay2
  static bool isValidMostroUrl(String url) {
    if (!url.startsWith('mostro:')) return false;
    
    try {
      final uri = Uri.parse(url);
      if (uri.scheme != 'mostro') return false;
      
      // Check if we have an order ID (path)
      final orderId = uri.path;
      if (orderId.isEmpty) return false;
      
      // Check if relays parameter exists
      final relaysParam = uri.queryParameters['relays'];
      if (relaysParam == null || relaysParam.isEmpty) return false;
      
      // Validate relay URLs
      final relays = relaysParam.split(',');
      for (final relay in relays) {
        final trimmedRelay = relay.trim();
        if (!trimmedRelay.startsWith('wss://') && !trimmedRelay.startsWith('ws://')) {
          return false;
        }
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Parses a mostro: URL and returns order information
  /// Format: mostro:order-id&relays=wss://relay1,wss://relay2
  /// Returns a map with 'orderId' and 'relays' keys
  static Map<String, dynamic>? parseMostroUrl(String url) {
    if (!isValidMostroUrl(url)) return null;

    try {
      final uri = Uri.parse(url);
      
      final orderId = uri.path;
      final relaysParam = uri.queryParameters['relays'];
      
      if (orderId.isEmpty || relaysParam == null) return null;
      
      final relays = relaysParam
          .split(',')
          .map((relay) => relay.trim())
          .where((relay) => relay.isNotEmpty)
          .toList();
      
      return {
        'orderId': orderId,
        'relays': relays,
      };
    } catch (e) {
      return null;
    }
  }

  static Future<String?> pubKeyFromIdentifierNip05(
      String internetIdentifier) async {
    return await _instance.services.utils
        .pubKeyFromIdentifierNip05(internetIdentifier: internetIdentifier);
  }

  // Método para generar el ID de un evento en Nostr
  static String generateId(Map<String, dynamic> eventData) {
    final jsonString = jsonEncode([
      0, // Versión del evento
      eventData['pubkey'], // Clave pública
      eventData['created_at'], // Marca de tiempo
      eventData['kind'], // Tipo de evento
      eventData['tags'], // Tags del evento
      eventData['content'] // Contenido del evento
    ]);

    // Cálculo del hash SHA-256 para generar el ID
    final bytes = utf8.encode(jsonString);
    final digest = sha256.convert(bytes);

    return digest.toString(); // Devuelve el ID como una cadena hex
  }

  /// Generates a timestamp between now and 48 hours ago to enhance privacy
  /// by decorrelating event timing from creation time.
  /// @throws if system clock is ahead of network time
  static DateTime randomNow() {
    final now = DateTime.now();
    // Validate system time isn't ahead
    final networkTime = DateTime.now().toUtc();
    if (now.isAfter(networkTime.add(Duration(minutes: 5)))) {
      throw Exception('System clock is ahead of network time');
    }
    final randomSeconds = Random().nextInt(2 * 24 * 60 * 60);
    return now.subtract(Duration(seconds: randomSeconds));
  }

  static Future<String> createRumor(NostrKeyPairs senderKeyPair,
      String wrapperKey, String recipientPubKey, String content) async {
    final rumorEvent = NostrEvent.fromPartialData(
      kind: 1,
      keyPairs: senderKeyPair,
      content: content,
      createdAt: DateTime.now(),
      tags: [
        ["p", recipientPubKey]
      ],
    );

    try {
      return await encryptNIP44(
          jsonEncode(rumorEvent.toMap()), wrapperKey, recipientPubKey);
    } catch (e) {
      throw Exception('Failed to encrypt content: $e');
    }
  }

  static Future<String> createSeal(
      NostrKeyPairs senderKeyPair,
      String wrapperKey,
      String recipientPubKey,
      String encryptedContent) async {
    final sealEvent = NostrEvent.fromPartialData(
      kind: 13,
      keyPairs: senderKeyPair,
      content: encryptedContent,
      createdAt: randomNow(),
    );

    return await encryptNIP44(
        jsonEncode(sealEvent.toMap()), wrapperKey, recipientPubKey);
  }

  static Future<NostrEvent> createWrap(NostrKeyPairs wrapperKeyPair,
      String sealedContent, String recipientPubKey) async {
    final wrapEvent = NostrEvent.fromPartialData(
      kind: 1059,
      content: sealedContent,
      keyPairs: wrapperKeyPair,
      tags: [
        ["p", recipientPubKey]
      ],
      createdAt: randomNow(),
    );

    return wrapEvent;
  }

  static NostrKeyPairs computeSharedKey(String privateKey, String publicKey) {
    final sharedKey = Nip44.computeSharedSecret(privateKey, publicKey);
    final nkey = hex.encode(sharedKey);
    return NostrKeyPairs(private: nkey);
  }

  /// Creates a NIP-59 encrypted event with the following structure:
  /// 1. Inner event (kind 1): Original content
  /// 2. Seal event (kind 13): Encrypted inner event
  /// 3. Wrapper event (kind 1059): Final encrypted package
  static Future<NostrEvent> createNIP59Event(
      String content, String recipientPubKey, String senderPrivateKey) async {
    // Validate inputs
    if (content.isEmpty) throw ArgumentError('Content cannot be empty');
    if (recipientPubKey.length != 64) {
      throw ArgumentError('Invalid recipient public key');
    }
    if (!isValidPrivateKey(senderPrivateKey)) {
      throw ArgumentError('Invalid sender private key');
    }

    final senderKeyPair = generateKeyPairFromPrivateKey(senderPrivateKey);

    String encryptedContent = await createRumor(
        senderKeyPair, senderKeyPair.private, recipientPubKey, content);

    final wrapperKeyPair = generateKeyPair();

    String sealedContent = await createSeal(senderKeyPair,
        wrapperKeyPair.private, recipientPubKey, encryptedContent);

    final wrapEvent =
        await createWrap(wrapperKeyPair, sealedContent, recipientPubKey);

    return wrapEvent;
  }

  static Future<NostrEvent> decryptNIP59Event(
      NostrEvent event, String privateKey) async {
    if (event.kind != 1059) {
      throw ArgumentError('Wrong kind: ${event.kind}');
    }
    // Validate inputs
    if (event.content == null || event.content!.isEmpty) {
      throw ArgumentError('Event content is empty');
    }
    if (!isValidPrivateKey(privateKey)) {
      throw ArgumentError('Invalid private key');
    }

    try {
      final decryptedContent = await decryptNIP44(
        event.content!,
        privateKey,
        event.pubkey,
      );

      final rumorEvent =
          NostrEvent.deserialized('["EVENT", "", $decryptedContent]');

      final finalDecryptedContent = await decryptNIP44(
        rumorEvent.content!,
        privateKey,
        rumorEvent.pubkey,
      );

      final wrap = jsonDecode(finalDecryptedContent) as Map<String, dynamic>;

      // Validate decrypted event structure
      _validateEventStructure(wrap);

      return NostrEvent(
        id: wrap['id'] as String,
        kind: wrap['kind'] as int,
        content: wrap['content'] as String,
        sig: "",
        pubkey: wrap['pubkey'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (wrap['created_at'] as int) * 1000,
        ),
        tags: List<List<String>>.from(
          (wrap['tags'] as List)
              .map(
                (nestedElem) => (nestedElem as List)
                    .map(
                      (nestedElemContent) => nestedElemContent.toString(),
                    )
                    .toList(),
              )
              .toList(),
        ),
        subscriptionId: '',
      );
    } catch (e) {
      throw Exception('Failed to decrypt NIP-59 event: $e');
    }
  }

  /// Validates the structure of a decrypted event
  static void _validateEventStructure(Map<String, dynamic> event) {
    final requiredFields = [
      'id',
      'kind',
      'content',
      'pubkey',
      'created_at',
      'tags'
    ];
    for (final field in requiredFields) {
      if (!event.containsKey(field)) {
        throw FormatException('Missing required field: $field');
      }
    }
  }

  static Future<String> encryptNIP44(
      String content, String privkey, String pubkey) async {
    try {
      return await Nip44.encryptMessage(content, privkey, pubkey);
    } catch (e) {
      // Handle encryption error appropriately
      throw Exception('Encryption failed: $e');
    }
  }

  static Future<String> decryptNIP44(
      String encryptedContent, String privkey, String pubkey) async {
    try {
      return await Nip44.decryptMessage(encryptedContent, privkey, pubkey);
    } catch (e) {
      // Handle encryption error appropriately
      throw Exception('Decryption failed: $e');
    }
  }
}
