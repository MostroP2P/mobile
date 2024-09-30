import '../../core/utils/auth_utils.dart';
import '../../core/utils/nostr_utils.dart';

class AuthRepository {
  Future<void> register(String privateKey, String password) async {
    if (!NostrUtils.isValidPrivateKey(privateKey)) {
      throw Exception('Invalid private key');
    }
    await AuthUtils.savePrivateKeyAndPassword(privateKey, password);
  }

  Future<bool> login(String password) async {
    return await AuthUtils.verifyPassword(password);
  }

  Future<String?> getPrivateKey() async {
    return await AuthUtils.getPrivateKey();
  }

  Future<void> logout() async {
    await AuthUtils.deleteCredentials();
  }

  Future<bool> isRegistered() async {
    final privateKey = await getPrivateKey();
    return privateKey != null;
  }
}
