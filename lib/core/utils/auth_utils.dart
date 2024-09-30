import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class AuthUtils {
  static const _storage = FlutterSecureStorage();

  static Future<void> savePrivateKeyAndPassword(
      String privateKey, String password) async {
    final hashedPassword = _hashPassword(password);
    await _storage.write(key: 'user_private_key', value: privateKey);
    await _storage.write(key: 'user_password_hash', value: hashedPassword);
  }

  static Future<String?> getPrivateKey() async {
    return await _storage.read(key: 'user_private_key');
  }

  static Future<bool> verifyPassword(String inputPassword) async {
    final storedHash = await _storage.read(key: 'user_password_hash');
    if (storedHash == null) return false;
    return _hashPassword(inputPassword) == storedHash;
  }

  static Future<void> deleteCredentials() async {
    await _storage.delete(key: 'user_private_key');
    await _storage.delete(key: 'user_password_hash');
  }

  static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
