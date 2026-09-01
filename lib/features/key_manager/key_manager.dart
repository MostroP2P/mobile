import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter/foundation.dart';
import 'package:mostro_mobile/features/key_manager/key_derivator.dart';
import 'package:mostro_mobile/features/key_manager/key_storage.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_errors.dart';

class KeyManager {
  final KeyStorage _storage;
  final KeyDerivator _derivator;

  NostrKeyPairs? masterKeyPair;
  String? _masterKeyHex;
  int? tradeKeyIndex;

  /// Memoized trade keys: derivation per index is deterministic and costs
  /// base58 + CKD + an EC multiplication each time. Cleared whenever the
  /// master key changes.
  final Map<int, NostrKeyPairs> _tradeKeyCache = {};

  /// Test hook: prime the in-memory master key without touching secure
  /// storage. Clears the trade-key memo like a real master-key change.
  @visibleForTesting
  void debugSetMasterKey(String extendedPrivateKey) {
    _masterKeyHex = extendedPrivateKey;
    _tradeKeyCache.clear();
    masterKeyPair =
        NostrKeyPairs(private: _derivator.derivePrivateKey(extendedPrivateKey, 0));
  }

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
    _masterKeyHex = masterKeyHex;
    _tradeKeyCache.clear();
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
    final masterKeyHex = _masterKeyHex ??= await _storage.readMasterKey();
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
    return _tradeKeyCache.putIfAbsent(
      index,
      () => NostrKeyPairs(
        private: _derivator.derivePrivateKey(_masterKeyHex!, index),
      ),
    );
  }

  /// Derive a trade key for a specific index
  Future<NostrKeyPairs> deriveTradeKeyFromIndex(int index) async {
    final masterKeyHex = _masterKeyHex ??= await _storage.readMasterKey();
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

  Future<bool> hasPersistedTradeKeyIndex() async {
    return _storage.hasPersistedTradeKeyIndex();
  }

  /// Reserve and return the next free trade key index, advancing the counter
  /// past it.
  ///
  /// The stored counter is the index [deriveTradeKey] will hand out next, so
  /// the reserved index must be that value — returning `currentIndex + 1`
  /// while storing `currentIndex + 1` handed the very same index to the next
  /// [deriveTradeKey] call. Two live sessions then shared a trade key, and
  /// with a common counterparty also the ECDH shared key the chat envelope is
  /// derived from, so one conversation surfaced as two chat rooms.
  Future<int> getNextKeyIndex() async {
    final currentIndex = await getCurrentKeyIndex();
    await setCurrentKeyIndex(currentIndex + 1);

    return currentIndex;
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
}
