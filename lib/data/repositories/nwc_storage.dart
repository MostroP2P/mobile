import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mostro_mobile/data/models/enums/storage_keys.dart';

/// Securely stores NWC connection URIs using FlutterSecureStorage.
///
/// Follows the same pattern as [KeyStorage] for consistent secure
/// data management across the app.
class NwcStorage {
  final FlutterSecureStorage secureStorage;

  NwcStorage({required this.secureStorage});

  /// Saves an NWC connection URI to secure storage.
  Future<void> saveConnection(String uri) async {
    await secureStorage.write(
      key: SecureStorageKeys.nwcConnectionUri.value,
      value: uri,
    );
  }

  /// Reads the stored NWC connection URI, or null if none exists.
  Future<String?> readConnection() async {
    return secureStorage.read(
      key: SecureStorageKeys.nwcConnectionUri.value,
    );
  }

  /// Deletes the stored NWC connection URI.
  Future<void> deleteConnection() async {
    await secureStorage.delete(
      key: SecureStorageKeys.nwcConnectionUri.value,
    );
  }

  /// Returns true if an NWC connection URI is stored.
  Future<bool> hasConnection() async {
    final uri = await readConnection();
    return uri != null && uri.isNotEmpty;
  }
}
