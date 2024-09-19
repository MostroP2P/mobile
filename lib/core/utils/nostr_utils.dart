import 'package:dart_nostr/dart_nostr.dart';
import 'package:cryptography/cryptography.dart';
import 'dart:math';
import 'dart:convert';

class NostrUtils {
  static String generatePrivateKey() {
    final keyPair = Nostr.instance.keysService.generateKeyPair();
    return Nostr.instance.keysService.encodePrivateKeyToNsec(keyPair.private);
  }

  static String nsecToHex(String nsec) {
    return Nostr.instance.keysService.decodeNsecKeyToPrivateKey(nsec);
  }

  static String hexToNsec(String hex) {
    return Nostr.instance.keysService.encodePrivateKeyToNsec(hex);
  }

  static List<int> generateRandomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  static Future<List<int>> aesEncrypt(
      String plaintext, List<int> key, List<int> iv) async {
    final algorithm = AesGcm.with256bits();
    final secretKey = SecretKey(key);
    final nonce = iv;

    final encrypted = await algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
      nonce: nonce,
    );

    return encrypted.cipherText;
  }

  static Future<String> aesDecrypt(
      List<int> ciphertext, List<int> key, List<int> iv) async {
    final algorithm = AesGcm.with256bits();
    final secretKey = SecretKey(key);
    final nonce = iv;

    final decrypted = await algorithm.decrypt(
      SecretBox(ciphertext, nonce: nonce, mac: const Mac([])),
      secretKey: secretKey,
    );

    return utf8.decode(decrypted);
  }
}
