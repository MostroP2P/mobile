class AuthUtils {
  static Future<void> savePrivateKeyAndPin(
      String privateKey, String pin) async {}

  static Future<String?> getPrivateKey() async {
    return null;
  }

  static Future<bool> verifyPin(String inputPin) async {
    return true;
  }

  static Future<void> deleteCredentials() async {}

  static Future<void> enableBiometrics() async {}

  static Future<bool> isBiometricsEnabled() async {
    return true;
  }
}
