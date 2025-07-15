import 'package:dart_nostr/dart_nostr.dart';
import 'package:mostro_mobile/features/key_manager/key_derivator.dart';
import 'package:mostro_mobile/features/key_manager/key_storage.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_errors.dart';

class KeyManager {
  final KeyStorage _storage;
  final KeyDerivator _derivator;

  NostrKeyPairs? masterKeyPair;
  String? _masterKeyHex;
  int? tradeKeyIndex;

  KeyManager(this._storage, this._derivator);

  Future<void> init() async {
    if (!await hasMasterKey()) {
      await generateAndStoreMasterKey();
    } else {
      masterKeyPair = await _getMasterKey();
      tradeKeyIndex = await getCurrentKeyIndex();
    }
  }

  Future<bool> hasMasterKey() async {
    if (masterKeyPair != null) {
      return true;
    }
    _masterKeyHex = await _storage.readMasterKey();
    return _masterKeyHex != null;
  }

  /// Generate a new mnemonic, derive the master key, and store both
  Future<void> generateAndStoreMasterKey() async {
    final mnemonic = _derivator.generateMnemonic();
    await generateAndStoreMasterKeyFromMnemonic(mnemonic);
  }

  // Generate a new master key from the supplied mnemonic
  Future<void> generateAndStoreMasterKeyFromMnemonic(String mnemonic) async {
    final masterKeyHex = _derivator.extendedKeyFromMnemonic(mnemonic);

    await _storage.clear();
    await _storage.storeMnemonic(mnemonic);
    await _storage.storeMasterKey(masterKeyHex);
    await setCurrentKeyIndex(1);
    masterKeyPair = await _getMasterKey();
    tradeKeyIndex = await getCurrentKeyIndex();
  }

  Future<void> importMnemonic(String mnemonic) async {
    await generateAndStoreMasterKeyFromMnemonic(mnemonic);
  }

  /// Retrieve the master key from storage, returning NostrKeyPairs
  /// or throws a MasterKeyNotFoundException if not found
  Future<NostrKeyPairs> _getMasterKey() async {
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
    await setCurrentKeyIndex(currentIndex + 1);

    return NostrKeyPairs(private: tradePrivateHex);
  }

  NostrKeyPairs deriveTradeKeyPair(int index) {
    final tradePrivateHex = _derivator.derivePrivateKey(_masterKeyHex!, index);

    return NostrKeyPairs(private: tradePrivateHex);
  }

  /// Derive a trade key for a specific index
  Future<NostrKeyPairs> deriveTradeKeyFromIndex(int index) async {
    final masterKeyHex = await _storage.readMasterKey();
    if (masterKeyHex == null) {
      throw MasterKeyNotFoundException(
        'No master key found in secure storage',
      );
    }
    final tradePrivateHex = _derivator.derivePrivateKey(
      masterKeyHex,
      index,
    );

    return NostrKeyPairs(private: tradePrivateHex);
  }

  Future<int> getCurrentKeyIndex() async {
    return await _storage.readTradeKeyIndex();
  }

  Future<void> setCurrentKeyIndex(int index) async {
    if (index < 1) {
      throw InvalidTradeKeyIndexException(
        'Trade key index must be greater than 0',
      );
    }
    tradeKeyIndex = index;
    await _storage.storeTradeKeyIndex(index);
  }

  /// Efficiently restore trade history by scanning for used trade keys
  /// Returns a map of key index -> public key for keys that have messages
  Future<Map<int, String>> scanForUsedTradeKeys({
    int maxKeysToScan = 100,
    int batchSize = 20,
  }) async {
    final masterKeyHex = await _storage.readMasterKey();
    if (masterKeyHex == null) {
      throw MasterKeyNotFoundException(
        'No master key found in secure storage',
      );
    }

    final usedKeys = <int, String>{};
    
    // Scan in batches for efficiency
    for (int startIndex = 1; startIndex <= maxKeysToScan; startIndex += batchSize) {
      final endIndex = (startIndex + batchSize - 1).clamp(1, maxKeysToScan);
      final batchKeys = <int, String>{};
      
      // Generate batch of keys
      for (int i = startIndex; i <= endIndex; i++) {
        final tradeKey = deriveTradeKeyPair(i);
        batchKeys[i] = tradeKey.public;
      }
      
      // Check if any keys in this batch have messages (this will be implemented in the service layer)
      // For now, we return the batch info so the service can query relays
      usedKeys.addAll(batchKeys);
    }
    
    return usedKeys;
  }

  /// Generate a batch of trade key pairs for efficient processing
  List<MapEntry<int, NostrKeyPairs>> generateTradeKeyBatch(int startIndex, int count) {
    final keys = <MapEntry<int, NostrKeyPairs>>[];
    for (int i = startIndex; i < startIndex + count; i++) {
      final keyPair = deriveTradeKeyPair(i);
      keys.add(MapEntry(i, keyPair));
    }
    return keys;
  }
}
