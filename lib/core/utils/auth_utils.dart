class AuthUtils {
  static Future<void> savePrivateKeyAndPin(
      String privateKey, String pin) async {}

  static Future<String?> getPrivateKey() async {
    return null;
  }

  static Future<bool> verifyPin(String inputPin) async {
    throw UnimplementedError('verifyPin is not implemented yet');
  }

  static Future<void> deleteCredentials() async {
    throw UnimplementedError('deleteCredentials is not implemented yet');
  }

  static Future<void> enableBiometrics() async {}

  static Future<bool> isBiometricsEnabled() async {
    throw UnimplementedError('isBiometricsEnabled is not implemented yet');
  }
}
