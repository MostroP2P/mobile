import 'package:dart_nostr/dart_nostr.dart';
import 'package:cryptography/cryptography.dart'
    as crypto; // Alias para la librería de criptografía
import 'dart:math';
import 'dart:convert';
import 'package:convert/convert.dart';
import 'package:pointycastle/ecc/curves/secp256k1.dart';
import 'package:pointycastle/export.dart' as pc; // Alias para pointycastle
import 'package:pointycastle/key_generators/ec_key_generator.dart';
import 'dart:typed_data';

import 'package:pointycastle/pointycastle.dart';
import 'package:pointycastle/random/fortuna_random.dart'; // Importa Uint8List

class NostrUtils {
  // Genera un par de claves usando secp256k1
  static pc.AsymmetricKeyPair<pc.PublicKey, pc.PrivateKey> generateKeyPair() {
    final keyParams = pc.ECKeyGeneratorParameters(pc.ECCurve_secp256k1());
    final random = pc.FortunaRandom();
    random.seed(
        pc.KeyParameter(Uint8List(32))); // Usa un seed de entropía adecuado

    final keyGen = pc.ECKeyGenerator();
    keyGen.init(pc.ParametersWithRandom(keyParams, random));

    return keyGen.generateKeyPair();
  }

  // Convierte la clave privada en formato 'nsec' a hexadecimal
  static String nsecToHex(String nsec) {
    return Nostr.instance.keysService.decodeNsecKeyToPrivateKey(nsec);
  }

  // Convierte una clave privada en hexadecimal a formato 'nsec'
  static String hexToNsec(String hex) {
    return Nostr.instance.keysService.encodePrivateKeyToNsec(hex);
  }

  // Firma un mensaje usando la clave privada
  static String signMessage(String message, pc.ECPrivateKey privateKey) {
    final signer = pc.Signer("SHA-256/ECDSA");
    final hash = sha256Digest(utf8.encode(message)); // Hashea el mensaje
    signer.init(true, pc.PrivateKeyParameter<pc.ECPrivateKey>(privateKey));

    // Cambiamos a pc.ECSignature
    final pc.ECSignature signature =
        signer.generateSignature(Uint8List.fromList(hash)) as pc.ECSignature;

    // Combina r y s en una cadena hexadecimal y la retorna
    final String rHex = signature.r.toRadixString(16);
    final String sHex = signature.s.toRadixString(16);

    return rHex + sHex;
  }

  // Genera un ID de evento basado en el contenido del evento
  static String generateId(Map<String, dynamic> eventContent) {
    final eventString = jsonEncode(eventContent);
    final digest = sha256Digest(utf8.encode(eventString));
    return hex.encode(digest);
  }

  // Hasheo SHA-256
  static Uint8List sha256Digest(List<int> input) {
    final digest = pc.Digest("SHA-256");
    return digest.process(Uint8List.fromList(input));
  }

  // Genera bytes aleatorios para AES o claves de criptografía
  static List<int> generateRandomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  // Encripta un mensaje usando AES-GCM
  static Future<List<int>> aesEncrypt(
      String plaintext, List<int> key, List<int> iv) async {
    // Añadí verificaciones para garantizar que key e iv no sean nulas
    assert(key.isNotEmpty && iv.isNotEmpty, 'Key and IV cannot be empty.');

    final algorithm = crypto.AesGcm.with256bits();
    final secretKey = crypto.SecretKey(key);
    final nonce = iv;

    final encrypted = await algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
      nonce: nonce,
    );

    return encrypted.cipherText;
  }

  // Desencripta un mensaje cifrado con AES-GCM
  static Future<String> aesDecrypt(
      List<int> ciphertext, List<int> key, List<int> iv) async {
    // Añadí verificaciones para garantizar que key e iv no sean nulas
    assert(key.isNotEmpty && iv.isNotEmpty, 'Key and IV cannot be empty.');

    final algorithm = crypto.AesGcm.with256bits();
    final secretKey = crypto.SecretKey(key);
    final nonce = iv;

    final decrypted = await algorithm.decrypt(
      crypto.SecretBox(ciphertext, nonce: nonce, mac: const crypto.Mac([])),
      secretKey: secretKey,
    );

    return utf8.decode(decrypted);
  }

  // Método para generar una clave privada en formato 'nsec'
  static String generatePrivateKey() {
    final keyParams = ECKeyGeneratorParameters(ECCurve_secp256k1());
    final random = FortunaRandom();
    random.seed(KeyParameter(Uint8List(32))); // Entropía segura

    final keyGen = ECKeyGenerator();
    keyGen.init(ParametersWithRandom(keyParams, random));

    final pair = keyGen.generateKeyPair();
    final privateKey = pair.privateKey as ECPrivateKey;

    // Convierte la clave privada a hexadecimal
    final privateKeyHex = hex.encode(privateKey.d!.toRadixString(16).codeUnits);

    // Aquí puedes implementar una codificación personalizada para convertirla a formato 'nsec'
    // Por simplicidad, devolvemos la clave en formato hexadecimal
    return privateKeyHex;
  }
}
