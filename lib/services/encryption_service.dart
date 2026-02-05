import 'dart:typed_data';
import 'dart:math';
import 'package:pointycastle/export.dart';
import 'package:mostro_mobile/services/logger_service.dart';

class EncryptionResult {
  final Uint8List encryptedData;
  final Uint8List nonce;
  final Uint8List authTag;

  EncryptionResult({
    required this.encryptedData,
    required this.nonce,
    required this.authTag,
  });

  /// Combine encrypted data and auth tag into a single blob for storage
  Uint8List toBlob() {
    final blob = Uint8List(nonce.length + encryptedData.length + authTag.length);
    int offset = 0;
    
    // Structure: [nonce][encrypted_data][auth_tag]
    blob.setRange(offset, offset + nonce.length, nonce);
    offset += nonce.length;
    
    blob.setRange(offset, offset + encryptedData.length, encryptedData);
    offset += encryptedData.length;
    
    blob.setRange(offset, offset + authTag.length, authTag);
    
    return blob;
  }

  /// Extract components from a blob
  static EncryptionResult fromBlob(Uint8List blob) {
    if (blob.length < 28) { // 12 (nonce) + 16 (auth tag) = minimum 28 bytes
      throw ArgumentError('Blob too small for ChaCha20-Poly1305');
    }

    const nonceLength = 12;
    const authTagLength = 16;
    
    final nonce = blob.sublist(0, nonceLength);
    final authTag = blob.sublist(blob.length - authTagLength);
    final encryptedData = blob.sublist(nonceLength, blob.length - authTagLength);

    return EncryptionResult(
      encryptedData: encryptedData,
      nonce: nonce,
      authTag: authTag,
    );
  }
}

class EncryptionService {
  static final SecureRandom _secureRandom = SecureRandom('Fortuna')
    ..seed(KeyParameter(_generateSeed()));

  /// Generate cryptographically secure random bytes
  static Uint8List generateSecureRandom(int length) {
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = _secureRandom.nextUint8();
    }
    return bytes;
  }

  /// Generate random seed for SecureRandom
  static Uint8List _generateSeed() {
    final random = Random.secure();
    final seed = Uint8List(32);
    for (int i = 0; i < seed.length; i++) {
      seed[i] = random.nextInt(256);
    }
    return seed;
  }

  /// Encrypt data using ChaCha20-Poly1305
  static EncryptionResult encryptChaCha20Poly1305({
    required Uint8List key,
    required Uint8List plaintext,
    Uint8List? nonce,
    Uint8List? additionalData,
  }) {
    if (key.length != 32) {
      throw ArgumentError('ChaCha20 key must be 32 bytes');
    }

    // Generate nonce if not provided
    nonce ??= generateSecureRandom(12);
    if (nonce.length != 12) {
      throw ArgumentError('ChaCha20-Poly1305 nonce must be 12 bytes');
    }

    logger.d('Encrypting ${plaintext.length} bytes with ChaCha20-Poly1305');

    try {
      // Create ChaCha20-Poly1305 cipher
      final cipher = ChaCha20Poly1305(ChaCha7539Engine(), Poly1305());
      
      // Initialize with key and nonce
      final params = AEADParameters(
        KeyParameter(key),
        128, // 128-bit authentication tag
        nonce,
        additionalData ?? Uint8List(0),
      );
      
      cipher.init(true, params); // true for encryption

      // Encrypt the data
      final output = Uint8List(cipher.getOutputSize(plaintext.length));
      int len = cipher.processBytes(plaintext, 0, plaintext.length, output, 0);
      len += cipher.doFinal(output, len);

      // Split encrypted data and authentication tag
      final encryptedData = output.sublist(0, plaintext.length);
      final authTag = output.sublist(plaintext.length, len);

      logger.i('✅ Encryption successful: ${encryptedData.length} bytes + ${authTag.length} bytes tag');

      return EncryptionResult(
        encryptedData: encryptedData,
        nonce: nonce,
        authTag: authTag,
      );
    } catch (e) {
      logger.e('❌ ChaCha20-Poly1305 encryption failed: $e');
      throw EncryptionException('Encryption failed: $e');
    }
  }

  /// Decrypt data using ChaCha20-Poly1305
  static Uint8List decryptChaCha20Poly1305({
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List encryptedData,
    required Uint8List authTag,
    Uint8List? additionalData,
  }) {
    if (key.length != 32) {
      throw ArgumentError('ChaCha20 key must be 32 bytes');
    }
    if (nonce.length != 12) {
      throw ArgumentError('ChaCha20-Poly1305 nonce must be 12 bytes');
    }
    if (authTag.length != 16) {
      throw ArgumentError('Poly1305 authentication tag must be 16 bytes');
    }

    logger.d('Decrypting ${encryptedData.length} bytes with ChaCha20-Poly1305');

    try {
      // Create ChaCha20-Poly1305 cipher
      final cipher = ChaCha20Poly1305(ChaCha7539Engine(), Poly1305());
      
      // Initialize with key and nonce
      final params = AEADParameters(
        KeyParameter(key),
        128, // 128-bit authentication tag
        nonce,
        additionalData ?? Uint8List(0),
      );
      
      cipher.init(false, params); // false for decryption

      // Combine encrypted data and auth tag for input
      final cipherInput = Uint8List(encryptedData.length + authTag.length);
      cipherInput.setRange(0, encryptedData.length, encryptedData);
      cipherInput.setRange(encryptedData.length, cipherInput.length, authTag);

      // Decrypt the data
      final output = Uint8List(cipher.getOutputSize(cipherInput.length));
      int len = cipher.processBytes(cipherInput, 0, cipherInput.length, output, 0);
      len += cipher.doFinal(output, len);

      final decryptedData = output.sublist(0, len);
      
      logger.i('✅ Decryption successful: ${decryptedData.length} bytes');

      return decryptedData;
    } catch (e) {
      logger.e('❌ ChaCha20-Poly1305 decryption failed: $e');
      throw EncryptionException('Decryption failed: $e');
    }
  }

  /// Convenience method to encrypt and return a blob
  static Uint8List encryptToBlob({
    required Uint8List key,
    required Uint8List plaintext,
    Uint8List? additionalData,
  }) {
    final result = encryptChaCha20Poly1305(
      key: key,
      plaintext: plaintext,
      additionalData: additionalData,
    );
    return result.toBlob();
  }

  /// Convenience method to decrypt from a blob
  static Uint8List decryptFromBlob({
    required Uint8List key,
    required Uint8List blob,
    Uint8List? additionalData,
  }) {
    final result = EncryptionResult.fromBlob(blob);
    return decryptChaCha20Poly1305(
      key: key,
      nonce: result.nonce,
      encryptedData: result.encryptedData,
      authTag: result.authTag,
      additionalData: additionalData,
    );
  }
}

class EncryptionException implements Exception {
  final String message;
  EncryptionException(this.message);

  @override
  String toString() => 'EncryptionException: $message';
}