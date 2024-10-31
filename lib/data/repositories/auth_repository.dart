import '../../core/utils/auth_utils.dart';
import '../../core/utils/nostr_utils.dart';
import '../../core/utils/biometrics_helper.dart';

class AuthRepository {
  final BiometricsHelper _biometricsHelper;

  AuthRepository({required BiometricsHelper biometricsHelper})
      : _biometricsHelper = biometricsHelper;

  Future<void> register(
      String privateKey, String pin, bool useBiometrics) async {
    try {
      if (!NostrUtils.isValidPrivateKey(privateKey)) {
        throw Exception('Invalid private key');
      }
      await AuthUtils.savePrivateKeyAndPin(privateKey, pin);
      if (useBiometrics) {
        await AuthUtils.enableBiometrics();
      }
    } catch (e) {
      print('Error in AuthRepository.register: $e');
      rethrow; // Re-lanza el error para que pueda ser manejado en el Bloc
    }
  }

  Future<bool> login(String pin) async {
    if (await AuthUtils.isBiometricsEnabled()) {
      return await _biometricsHelper.authenticateWithBiometrics();
    }
    return await AuthUtils.verifyPin(pin);
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

  Future<bool> isBiometricsAvailable() async {
    return await _biometricsHelper.isBiometricsAvailable();
  }

  Future<String> generateNewIdentity() async {
    return NostrUtils.generatePrivateKey();
  }
}
