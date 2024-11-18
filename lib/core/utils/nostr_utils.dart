import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:elliptic/elliptic.dart';
import 'package:nip44/nip44.dart';

class NostrUtils {
  static final Nostr _instance = Nostr.instance;

  // Generación de claves
  static NostrKeyPairs generateKeyPair() {
    return NostrKeyPairs(private: generatePrivateKey());
  }

  static NostrKeyPairs generateKeyPairFromPrivateKey(String privateKey) {
    return _instance.keysService
        .generateKeyPairFromExistingPrivateKey(privateKey);
  }

  static String generatePrivateKey() {
    return getS256().generatePrivateKey().toHex();
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

  static String nsecToHex(String nsec) {
    if (nsec.startsWith('nsec')) {
      return decodeNsecKeyToPrivateKey(nsec);
    }
    return nsec; // Si ya es hex, devolverlo tal cual
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

  static DateTime randomNow() {
    final now = DateTime.now();
    final randomSeconds =
        Random().nextInt(2 * 24 * 60 * 60);
    return now.subtract(Duration(seconds: randomSeconds));
  }

  // NIP-59 y NIP-44 funciones
  static Future<NostrEvent> createNIP59Event(
      String content, String recipientPubKey, String senderPrivateKey) async {
    final senderKeyPair = generateKeyPairFromPrivateKey(senderPrivateKey);

    final createdAt = DateTime.now();
    final rumorEvent = NostrEvent.fromPartialData(
      kind: 1,
      keyPairs: senderKeyPair,
      content: content,
      createdAt: createdAt,
      tags: [
        ["p", recipientPubKey]
      ],
    );

    final encryptedContent = await _encryptNIP44(
        jsonEncode(rumorEvent.toMap()), senderPrivateKey, '02$recipientPubKey');

    final sealEvent = NostrEvent.fromPartialData(
      kind: 13,
      keyPairs: senderKeyPair,
      content: encryptedContent,
      createdAt: randomNow(),
    );

    final wrapperKeyPair = generateKeyPair();

    final pk = wrapperKeyPair.private;

    final sealedContent =
        _encryptNIP44(jsonEncode(sealEvent.toMap()), pk, '02$recipientPubKey');

    final wrapEvent = NostrEvent.fromPartialData(
      kind: 1059,
      content: await sealedContent,
      keyPairs: wrapperKeyPair,
      tags: [
        ["p", recipientPubKey]
      ],
      createdAt: createdAt,
    );

    return wrapEvent;
  }

  static Future<NostrEvent> decryptNIP59Event(
      NostrEvent event, String privateKey) async {
    final decryptedContent =
        await _decryptNIP44(event.content ?? '', privateKey, event.pubkey);

    final rumorEvent =
        NostrEvent.deserialized('["EVENT", "", $decryptedContent]');

    final finalDecryptedContent = await _decryptNIP44(
        rumorEvent.content ?? '', privateKey, rumorEvent.pubkey);

    final wrap = jsonDecode(finalDecryptedContent) as Map<String, dynamic>;

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
  }


  static Future<String> _encryptNIP44(
      String content, String privkey, String pubkey) async {
    return await Nip44.encryptMessage(content, privkey, pubkey);
  }

  static Future<String> _decryptNIP44(
      String encryptedContent, String privkey, String pubkey) async {
    return await Nip44.decryptMessage(encryptedContent, privkey, pubkey);
  }
}
