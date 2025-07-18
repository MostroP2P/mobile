class AuthUtils {
  /// Temporary implementation for alpha preview.
  /// WARNING: This is not secure and should not be used in production.
  /// TODO: Implement secure storage for credentials
  static Future<void> savePrivateKeyAndPin(
      String privateKey, String pin) async {}

  /// Temporary implementation for alpha preview.
  /// WARNING: This always returns null and should not be used in production.
  /// TODO: Implement secure key retrieval
  static Future<String?> getPrivateKey() async {
    return null;
  }

  static Future<bool> verifyPin(String inputPin) async {
    throw UnimplementedError('verifyPin is not implemented yet');
  }

  static Future<void> deleteCredentials() async {
    throw UnimplementedError('deleteCredentials is not implemented yet');
  }

  static Future<void> enableBiometrics() async {
    throw UnimplementedError('enableBiometrics is not implemented yet');
  }

  static Future<bool> isBiometricsEnabled() async {
    throw UnimplementedError('isBiometricsEnabled is not implemented yet');
  }
}
