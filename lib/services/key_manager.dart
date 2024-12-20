import 'package:bip32_bip44/dart_bip32_bip44.dart' as bip32;
import 'package:bip39/bip39.dart' as bip39;

class KeyManager {
  static String getPrivateKeyFromMnemonic(String mnemonic, int index) {
    final seed = bip39.mnemonicToSeedHex(mnemonic);
    final chain = bip32.Chain.seed(seed);

    final key =
        chain.forPath("m/44'/1237'/38383'/0/0") as bip32.ExtendedPrivateKey;
    final childKey = bip32.deriveExtendedPrivateChildKey(key, index);
    return (childKey.key != null) ? childKey.key!.toRadixString(16) : '';
  }

  static String generateMnemonic() {
    return bip39.generateMnemonic();
  }

  static bool isMnemonicValid(String text) {
    return bip39.validateMnemonic(text);
  }

}
