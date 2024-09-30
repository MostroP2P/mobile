import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dart_nostr/dart_nostr.dart';

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
}
