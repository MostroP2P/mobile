import 'package:bip39/bip39.dart' as bip39;
import 'package:bip32/bip32.dart' as bip32;
import 'package:convert/convert.dart';
import 'package:dart_nostr/dart_nostr.dart';

/// A utility class for generating, validating, and deriving keys
/// according to NIP-06
class KeyDerivator {
  final String derivationPath;

  KeyDerivator(this.derivationPath);

  String generateMnemonic() {
    return bip39.generateMnemonic();
  }

  bool isMnemonicValid(String mnemonic) {
    return bip39.validateMnemonic(mnemonic);
  }

  String masterPrivateKeyFromMnemonic(String mnemonic) {
    final seedHex = bip39.mnemonicToSeed(mnemonic);
    final node = bip32.BIP32.fromSeed(seedHex);
    final child = node.derivePath('$derivationPath/0');
    return hex.encode(child.privateKey!);
  }

  String extendedKeyFromMnemonic(String mnemonic) {
    final seed = bip39.mnemonicToSeed(mnemonic);
    final root = bip32.BIP32.fromSeed(seed);
    return root.toBase58();
  }

  String derivePrivateKey(String extendedPrivateKey, int index) {
    final root = bip32.BIP32.fromBase58(extendedPrivateKey);
    final child = root.derivePath('$derivationPath/$index');
    if (child.privateKey == null) {
      throw Exception(
          "Derived child key has no private key. Possibly a neutered node?");
    }
    return hex.encode(child.privateKey!);
  }

  String privateToPublicKey(String privateKeyHex) {
    final keyPairs = NostrKeyPairs(private: privateKeyHex);
    return keyPairs.public;
  }
}
