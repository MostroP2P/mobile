import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mostro_mobile/data/models/enums/storage_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

class KeyStorage {
  final FlutterSecureStorage secureStorage;
  final SharedPreferencesAsync sharedPrefs;

  KeyStorage({
    required this.secureStorage,
    required this.sharedPrefs,
  });

  Future<void> storeMasterKey(String masterKey) async {
    await secureStorage.write(
      key: SecureStorageKeys.masterKey.value,
      value: masterKey,
    );
  }

  Future<String?> readMasterKey() async {
    return secureStorage.read(
      key: SecureStorageKeys.masterKey.value,
    );
  }

  Future<void> storeMnemonic(String mnemonic) async {
    await secureStorage.write(
      key: SecureStorageKeys.mnemonic.value,
      value: mnemonic,
    );
  }

  Future<String?> readMnemonic() async {
    return secureStorage.read(
      key: SecureStorageKeys.mnemonic.value,
    );
  }

  Future<void> storeTradeKeyIndex(int index) async {
    await sharedPrefs.setInt(
      SharedPreferencesKeys.keyIndex.value,
      index,
    );
  }

  Future<int> readTradeKeyIndex() async {
    return await sharedPrefs.getInt(
          SharedPreferencesKeys.keyIndex.value,
        ) ??
        1;
  }

  Future<void> clear() async {
    await secureStorage.deleteAll();
    await sharedPrefs.clear();
  }
}
