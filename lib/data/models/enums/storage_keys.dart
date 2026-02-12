enum SharedPreferencesKeys {
  appSettings('mostro_settings'),
  keyIndex('key_index'),
  fullPrivacy('full_privacy'),
  firstRunComplete('first_run_complete'),
  mostroCustomNodes('mostro_custom_nodes'),
  mostroNodeMetadataCache('mostro_node_metadata_cache');

  final String value;

  const SharedPreferencesKeys(this.value);

  static final _valueMap = {
    for (var key in SharedPreferencesKeys.values) key.value: key
  };

  static SharedPreferencesKeys fromString(String value) {
    final key = _valueMap[value];
    if (key == null) {
      throw ArgumentError('Invalid Shared Preferences Key: $value');
    }
    return key;
  }

  @override
  String toString() {
    return value;
  }
}

enum SecureStorageKeys {
  masterKey('master_key'),
  mnemonic('mnemonic');

  final String value;

  const SecureStorageKeys(this.value);

  static final _valueMap = {
    for (var key in SecureStorageKeys.values) key.value: key
  };

  static SecureStorageKeys fromString(String value) {
    final key = _valueMap[value];
    if (key == null) {
      throw ArgumentError('Invalid Secure Storage Key: $value');
    }
    return key;
  }

  @override
  String toString() {
    return value;
  }
}
