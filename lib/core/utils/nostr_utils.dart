import 'package:dart_nostr/dart_nostr.dart';
import 'dart:convert';

class NostrUtils {
  static KeyPair generateKeyPair() {
    return Nostr.instance.keysService.generateKeyPair();
  }

  static String nsecToHex(String nsec) {
    return Nostr.instance.keysService.decodeNsecKeyToPrivateKey(nsec);
  }

  static String hexToNsec(String hex) {
    return Nostr.instance.keysService.encodePrivateKeyToNsec(hex);
  }

  static String signMessage(String message, String privateKey) {
    return Nostr.instance.keysService
        .sign(privateKey: privateKey, message: message);
  }

  static String generateId(Map<String, dynamic> eventContent) {
    final eventString = jsonEncode(eventContent);
    return Nostr.instance.utilsService.consistent64HexChars(eventString);
  }

  static String generatePrivateKey() {
    return Nostr.instance.keysService.generatePrivateKey();
  }
}
