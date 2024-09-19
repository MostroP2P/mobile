import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'dart:convert';
import '../../core/utils/nostr_utils.dart';

class AuthRepository {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final String _boxName = 'userBox';

  Future<void> register(String nsec, String password) async {
    final hex = NostrUtils.nsecToHex(nsec);
    final encryptedKey = await _encryptPrivateKey(hex, password);
    await _secureStorage.write(
        key: 'encryptedPrivateKey', value: jsonEncode(encryptedKey));

    // Almacenar el hash de la contraseña
    final passwordHash = await _hashPassword(password);
    await _secureStorage.write(key: 'passwordHash', value: passwordHash);

    final box = await Hive.openBox(_boxName);
    await box.put('isRegistered', true);
  }

  Future<String> login(String password) async {
    final passwordHash = await _secureStorage.read(key: 'passwordHash');
    if (passwordHash == null) {
      throw Exception('No password hash found');
    }

    if (!await _verifyPassword(password, passwordHash)) {
      throw Exception('Invalid password');
    }

    final encryptedKeyJson =
        await _secureStorage.read(key: 'encryptedPrivateKey');
    if (encryptedKeyJson == null) {
      throw Exception('No encrypted private key found');
    }

    final encryptedKey = jsonDecode(encryptedKeyJson);
    try {
      final decryptedKey = await _decryptPrivateKey(encryptedKey, password);
      return decryptedKey;
    } catch (e) {
      throw Exception('Failed to decrypt private key');
    }
  }

  Future<bool> isRegistered() async {
    final box = await Hive.openBox(_boxName);
    return box.get('isRegistered', defaultValue: false);
  }

  Future<void> deleteAccount() async {
    await _secureStorage.delete(key: 'encryptedPrivateKey');
    await _secureStorage.delete(key: 'passwordHash');
    final box = await Hive.openBox(_boxName);
    await box.delete('isRegistered');
  }

  Future<Map<String, String>> _encryptPrivateKey(
      String privateKey, String password) async {
    final salt = NostrUtils.generateRandomBytes(16);
    final key = await _deriveKey(password, salt);
    final iv = NostrUtils.generateRandomBytes(16);

    final encrypted = await NostrUtils.aesEncrypt(privateKey, key, iv);

    return {
      'salt': base64.encode(salt),
      'iv': base64.encode(iv),
      'ciphertext': base64.encode(encrypted),
    };
  }

  Future<String> _decryptPrivateKey(
      Map<String, dynamic> encryptedKey, String password) async {
    final salt = base64.decode(encryptedKey['salt']);
    final iv = base64.decode(encryptedKey['iv']);
    final ciphertext = base64.decode(encryptedKey['ciphertext']);

    final key = await _deriveKey(password, salt);

    return await NostrUtils.aesDecrypt(ciphertext, key, iv);
  }

  Future<List<int>> _deriveKey(String password, List<int> salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 100000,
      bits: 256,
    );
    final secretKey = SecretKey(utf8.encode(password));
    final keyBytes = await pbkdf2
        .deriveKey(secretKey: secretKey, nonce: salt)
        .then((key) => key.extractBytes());
    return keyBytes;
  }

  Future<String> _hashPassword(String password) async {
    final salt = NostrUtils.generateRandomBytes(16);
    final key = await _deriveKey(password, salt);
    return '${base64.encode(salt)}:${base64.encode(key)}';
  }

  Future<bool> _verifyPassword(String password, String storedHash) async {
    final parts = storedHash.split(':');
    if (parts.length != 2) return false;

    final salt = base64.decode(parts[0]);
    final storedKey = base64.decode(parts[1]);

    final key = await _deriveKey(password, salt);

    // Comparación segura contra ataques de tiempo
    if (key.length != storedKey.length) return false;
    var result = 0;
    for (var i = 0; i < key.length; i++) {
      result |= key[i] ^ storedKey[i];
    }
    return result == 0;
  }
}
