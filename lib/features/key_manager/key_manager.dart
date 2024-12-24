import 'package:dart_nostr/dart_nostr.dart';
import 'package:mostro_mobile/features/key_manager/key_derivator.dart';
import 'package:mostro_mobile/features/key_manager/key_storage.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_errors.dart';

class KeyManager {
  final KeyStorage _storage;
  final KeyDerivator _derivator;

  KeyManager(this._storage, this._derivator);

  Future<bool> hasMasterKey() async {
    final masterKeyHex = await _storage.readMasterKey();
    return masterKeyHex != null;
  }

  /// Generate a new mnemonic, derive the master key, and store both
  Future<void> generateAndStoreMasterKey() async {
    final mnemonic = _derivator.generateMnemonic();
    final masterKeyHex = _derivator.extendedKeyFromMnemonic(mnemonic);

    await _storage.storeMnemonic(mnemonic);
    await _storage.storeMasterKey(masterKeyHex);
    await _storage
        .storeTradeKeyIndex(1);
  }

  /// Retrieve the master key from storage, returning NostrKeyPairs
  /// or throws a MasterKeyNotFoundException if not found
  Future<NostrKeyPairs> getMasterKey() async {
    final masterKeyHex = await _storage.readMasterKey();
    if (masterKeyHex == null) {
      throw MasterKeyNotFoundException('No master key found in secure storage');
    }
    final privKey = _derivator.derivePrivateKey(masterKeyHex, 0);
    return NostrKeyPairs(private: privKey);
  }

  /// Return the stored mnemonic, or null if none
  Future<String?> getMnemonic() async {
    return _storage.readMnemonic();
  }

  Future<NostrKeyPairs> deriveTradeKey() async {
    final masterKeyHex = await _storage.readMasterKey();
    if (masterKeyHex == null) {
      throw MasterKeyNotFoundException('No master key found in secure storage');
    }
    final currentIndex = await _storage.readTradeKeyIndex();

    final tradePrivateHex =
        _derivator.derivePrivateKey(masterKeyHex, currentIndex);

    // increment index
    await _storage.storeTradeKeyIndex(currentIndex + 1);

    return NostrKeyPairs(private: tradePrivateHex);
  }

  /// Derive a trade key for a specific index
  Future<NostrKeyPairs> deriveTradeKeyFromIndex(int index) async {
    final masterKeyHex = await _storage.readMasterKey();
    if (masterKeyHex == null) {
      throw MasterKeyNotFoundException('No master key found in secure storage');
    }
    final tradePrivateHex = _derivator.derivePrivateKey(masterKeyHex, index);

    return NostrKeyPairs(private: tradePrivateHex);
  }

  Future<int> getCurrentKeyIndex() async {
    return await _storage.readTradeKeyIndex();
  }
}
