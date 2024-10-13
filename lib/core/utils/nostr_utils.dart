import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

class NostrUtils {
  static final Nostr _instance = Nostr.instance;

  // Generación de claves
  static NostrKeyPairs generateKeyPair() {
    return _instance.keysService.generateKeyPair();
  }

  static NostrKeyPairs generateKeyPairFromPrivateKey(String privateKey) {
    return _instance.keysService
        .generateKeyPairFromExistingPrivateKey(privateKey);
  }

  static String generatePrivateKey() {
    return _instance.keysService.generatePrivateKey();
  }

  // Codificación y decodificación de claves
  static String encodePrivateKeyToNsec(String privateKey) {
    return _instance.keysService.encodePrivateKeyToNsec(privateKey);
  }

  static String decodeNsecKeyToPrivateKey(String nsec) {
    return _instance.keysService.decodeNsecKeyToPrivateKey(nsec);
  }

  static String encodePublicKeyToNpub(String publicKey) {
    return _instance.keysService.encodePublicKeyToNpub(publicKey);
  }

  static String decodeNpubKeyToPublicKey(String npub) {
    return _instance.keysService.decodeNpubKeyToPublicKey(npub);
  }

  // Operaciones con claves
  static String derivePublicKey(String privateKey) {
    return _instance.keysService.derivePublicKey(privateKey: privateKey);
  }

  static bool isValidPrivateKey(String privateKey) {
    return _instance.keysService.isValidPrivateKey(privateKey);
  }

  // Firma y verificación
  static String signMessage(String message, String privateKey) {
    return _instance.keysService.sign(privateKey: privateKey, message: message);
  }

  static bool verifySignature(
      String signature, String message, String publicKey) {
    return _instance.keysService
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
    final result = _instance.utilsService.decodeBech32(bech32String);
    return result[1]; // Devuelve solo la parte de datos
  }

  static String encodeBech32(String hrp, String data) {
    return _instance.utilsService.encodeBech32(hrp, data);
  }

  static Future<String?> pubKeyFromIdentifierNip05(
      String internetIdentifier) async {
    return await _instance.utilsService
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

  // NIP-59 y NIP-44 funciones
  static NostrEvent createNIP59Event(
      String content, String recipientPubKey, String senderPrivateKey) {
    final senderKeyPair = generateKeyPairFromPrivateKey(senderPrivateKey);
    final sharedSecret =
        _calculateSharedSecret(senderPrivateKey, recipientPubKey);

    final encryptedContent = _encryptNIP44(content, sharedSecret);

    final createdAt = DateTime.now();
    final rumorEvent = NostrEvent(
      kind: 1059,
      pubkey: senderKeyPair.public,
      content: encryptedContent,
      tags: [
        ["p", recipientPubKey]
      ],
      createdAt: createdAt,
      id: '', // Se generará después
      sig: '', // Se generará después
    );

    // Generar ID y firma
    final id = generateId({
      'pubkey': rumorEvent.pubkey,
      'created_at': rumorEvent.createdAt!.millisecondsSinceEpoch ~/ 1000,
      'kind': rumorEvent.kind,
      'tags': rumorEvent.tags,
      'content': rumorEvent.content,
    });
    signMessage(id, senderPrivateKey);

    final wrapperKeyPair = generateKeyPair();
    final wrappedContent = _encryptNIP44(jsonEncode(rumorEvent.toMap()),
        _calculateSharedSecret(wrapperKeyPair.private, recipientPubKey));

    return NostrEvent(
      kind: 1059,
      pubkey: wrapperKeyPair.public,
      content: wrappedContent,
      tags: [
        ["p", recipientPubKey]
      ],
      createdAt: DateTime.now(),
      id: generateId({
        'pubkey': wrapperKeyPair.public,
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'kind': 1059,
        'tags': [
          ["p", recipientPubKey]
        ],
        'content': wrappedContent,
      }),
      sig: '', // Se generará automáticamente al publicar el evento
    );
  }

  static String decryptNIP59Event(NostrEvent event, String privateKey) {
    final sharedSecret = _calculateSharedSecret(privateKey, event.pubkey);
    final decryptedContent = _decryptNIP44(event.content ?? '', sharedSecret);

    final rumorEvent = NostrEvent.deserialized(decryptedContent);
    final rumorSharedSecret =
        _calculateSharedSecret(privateKey, rumorEvent.pubkey);
    final finalDecryptedContent =
        _decryptNIP44(rumorEvent.content ?? '', rumorSharedSecret);

    return finalDecryptedContent;
  }

  static Uint8List _calculateSharedSecret(String privateKey, String publicKey) {
    // Nota: Esta implementación puede necesitar ajustes dependiendo de cómo
    // dart_nostr maneje la generación de secretos compartidos.
    // Posiblemente necesites usar una biblioteca de criptografía adicional aquí.
    final sharedPoint = generateKeyPairFromPrivateKey(privateKey).public;
    return Uint8List.fromList(sha256.convert(utf8.encode(sharedPoint)).bytes);
  }

  static String _encryptNIP44(String content, Uint8List key) {
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(encrypt.Key(key)));
    final encrypted = encrypter.encrypt(content, iv: iv);
    return base64Encode(iv.bytes + encrypted.bytes);
  }

  static String _decryptNIP44(String encryptedContent, Uint8List key) {
    final decoded = base64Decode(encryptedContent);
    final iv = encrypt.IV(decoded.sublist(0, 16));
    final encryptedBytes = decoded.sublist(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(encrypt.Key(key)));
    return encrypter.decrypt64(base64Encode(encryptedBytes), iv: iv);
  }
}
