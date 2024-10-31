import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthUtils {
  static const _storage = FlutterSecureStorage();

  static Future<void> savePrivateKeyAndPin(String privateKey, String pin) async {
    await _storage.write(key: 'user_private_key', value: privateKey);
    await _storage.write(key: 'user_pin', value: pin);
  }

  static Future<String?> getPrivateKey() async {
    return await _storage.read(key: 'user_private_key');
  }

  static Future<bool> verifyPin(String inputPin) async {
    final storedPin = await _storage.read(key: 'user_pin');
    return storedPin == inputPin;
  }

  static Future<void> deleteCredentials() async {
    await _storage.delete(key: 'user_private_key');
    await _storage.delete(key: 'user_pin');
    await _storage.delete(key: 'use_biometrics');
  }

  static Future<void> enableBiometrics() async {
    await _storage.write(key: 'use_biometrics', value: 'true');
  }

  static Future<bool> isBiometricsEnabled() async {
    return await _storage.read(key: 'use_biometrics') == 'true';
  }
}