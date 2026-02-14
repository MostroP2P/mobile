import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:nip44/nip44.dart';
import 'package:pointycastle/export.dart';

/// Encryption mode for NWC communication.
enum NwcEncryption {
  /// NIP-04: AES-256-CBC with ECDH shared secret (legacy).
  nip04,

  /// NIP-44 v2: ChaCha20-Poly1305 (preferred).
  nip44,
}

/// Handles encryption/decryption for NWC protocol messages.
///
/// Supports both NIP-04 (legacy) and NIP-44 (preferred) as specified in NIP-47.
/// The encryption mode is determined by the wallet service's info event.
/// If no encryption tag is present, NIP-04 is assumed per the spec.
class NwcCrypto {
  /// Encrypts a plaintext message for the wallet service.
  static Future<String> encrypt(
    String plaintext,
    String senderPrivateKey,
    String receiverPublicKey,
    NwcEncryption mode,
  ) async {
    switch (mode) {
      case NwcEncryption.nip44:
        return Nip44.encryptMessage(
            plaintext, senderPrivateKey, receiverPublicKey);
      case NwcEncryption.nip04:
        return _encryptNip04(plaintext, senderPrivateKey, receiverPublicKey);
    }
  }

  /// Decrypts an encrypted message from the wallet service.
  static Future<String> decrypt(
    String ciphertext,
    String receiverPrivateKey,
    String senderPublicKey,
    NwcEncryption mode,
  ) async {
    switch (mode) {
      case NwcEncryption.nip44:
        return Nip44.decryptMessage(
            ciphertext, receiverPrivateKey, senderPublicKey);
      case NwcEncryption.nip04:
        return _decryptNip04(ciphertext, receiverPrivateKey, senderPublicKey);
    }
  }

  /// Detects encryption mode from event content format.
  ///
  /// NIP-04 content has the format: `base64?iv=base64`
  /// NIP-44 content is pure base64 without `?iv=`.
  static NwcEncryption detectFromContent(String content) {
    if (content.contains('?iv=')) {
      return NwcEncryption.nip04;
    }
    return NwcEncryption.nip44;
  }

  /// Returns the encryption tag value for NIP-47 events.
  static String encryptionTagValue(NwcEncryption mode) {
    switch (mode) {
      case NwcEncryption.nip44:
        return 'nip44_v2';
      case NwcEncryption.nip04:
        return 'nip04';
    }
  }

  // ---------------------------------------------------------------------------
  // NIP-04 implementation (AES-256-CBC with ECDH shared secret)
  // ---------------------------------------------------------------------------

  static String _encryptNip04(
    String plaintext,
    String privateKeyHex,
    String publicKeyHex,
  ) {
    final sharedSecret = _computeNip04SharedSecret(privateKeyHex, publicKeyHex);
    final iv = _generateRandomBytes(16);

    final cipher = CBCBlockCipher(AESEngine())
      ..init(true, ParametersWithIV(KeyParameter(sharedSecret), iv));

    final padded = _pkcs7Pad(utf8.encode(plaintext), 16);
    final encrypted = Uint8List(padded.length);

    for (var offset = 0; offset < padded.length; offset += 16) {
      cipher.processBlock(padded, offset, encrypted, offset);
    }

    final encryptedBase64 = base64.encode(encrypted);
    final ivBase64 = base64.encode(iv);
    return '$encryptedBase64?iv=$ivBase64';
  }

  static String _decryptNip04(
    String ciphertext,
    String privateKeyHex,
    String publicKeyHex,
  ) {
    final parts = ciphertext.split('?iv=');
    if (parts.length != 2) {
      throw ArgumentError('Invalid NIP-04 ciphertext format');
    }

    final encryptedBytes = base64.decode(parts[0]);
    final iv = base64.decode(parts[1]);
    final sharedSecret = _computeNip04SharedSecret(privateKeyHex, publicKeyHex);

    final cipher = CBCBlockCipher(AESEngine())
      ..init(false, ParametersWithIV(KeyParameter(sharedSecret), iv));

    final decrypted = Uint8List(encryptedBytes.length);
    for (var offset = 0; offset < encryptedBytes.length; offset += 16) {
      cipher.processBlock(encryptedBytes, offset, decrypted, offset);
    }

    return utf8.decode(_pkcs7Unpad(decrypted));
  }

  /// Computes the NIP-04 shared secret (ECDH on secp256k1, take x-coordinate).
  static Uint8List _computeNip04SharedSecret(
    String privateKeyHex,
    String publicKeyHex,
  ) {
    final domain = ECDomainParameters('secp256k1');

    final privateKey = ECPrivateKey(
      BigInt.parse(privateKeyHex, radix: 16),
      domain,
    );

    // Public key in NIP format is 32-byte x-coordinate (no prefix).
    // We need to reconstruct the full compressed public key (02 + x).
    final fullPubKeyHex = '02$publicKeyHex';
    final pubKeyBytes = _hexToBytes(fullPubKeyHex);
    final publicKey = ECPublicKey(
      domain.curve.decodePoint(pubKeyBytes),
      domain,
    );

    // ECDH: multiply private key by public key point
    final sharedPoint = publicKey.Q! * privateKey.d;
    final sharedX = sharedPoint!.x!.toBigInteger()!;

    // Convert to 32 bytes
    final bytes = _bigIntToBytes(sharedX, 32);
    return bytes;
  }

  static Uint8List _pkcs7Pad(List<int> data, int blockSize) {
    final padLength = blockSize - (data.length % blockSize);
    final padded = Uint8List(data.length + padLength);
    padded.setAll(0, data);
    for (var i = data.length; i < padded.length; i++) {
      padded[i] = padLength;
    }
    return padded;
  }

  static Uint8List _pkcs7Unpad(Uint8List data) {
    if (data.isEmpty) return data;
    final padLength = data.last;
    if (padLength > 16 || padLength == 0) return data;
    return Uint8List.fromList(data.sublist(0, data.length - padLength));
  }

  static Uint8List _generateRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => random.nextInt(256)),
    );
  }

  static Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }

  static Uint8List _bigIntToBytes(BigInt number, int length) {
    final hex = number.toRadixString(16).padLeft(length * 2, '0');
    return _hexToBytes(hex);
  }
}
