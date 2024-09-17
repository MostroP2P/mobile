import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Nostr _nostr = Nostr.instance;

  Future<void> initializeWithExistingKey(String privateKey) async {
    await _storage.write(key: 'private_key', value: privateKey);
    _nostr.keysService.initialize(privateKey);
  }

  Future<void> generateNewKey() async {
    final keyPair = _nostr.keysService.generateKeyPair();
    await _storage.write(key: 'private_key', value: keyPair.private);
    _nostr.keysService.initialize(keyPair.private);
  }

  Future<bool> hasKey() async {
    return await _storage.read(key: 'private_key') != null;
  }

  Future<String?> getPublicKey() async {
    final privateKey = await _storage.read(key: 'private_key');
    if (privateKey != null) {
      return _nostr.keysService.derivePublicKey(privateKey);
    }
    return null;
  }

  Future<void> logout() async {
    await _storage.delete(key: 'private_key');
    // You might want to reset the Nostr instance or perform other cleanup here
  }
}
