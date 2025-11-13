import 'package:bip39/bip39.dart' as bip39;

/// Validates a BIP39 mnemonic phrase
///
/// Returns true if the mnemonic is valid (correct words and checksum)
/// Returns false if invalid
bool validateMnemonic(String mnemonic) {
  try {
    final trimmed = mnemonic.trim();
    if (trimmed.isEmpty) {
      return false;
    }

    // bip39.validateMnemonic checks:
    // 1. Word count is 12, 15, 18, 21, or 24
    // 2. All words are in the BIP39 wordlist
    // 3. Checksum is valid
    return bip39.validateMnemonic(trimmed);
  } catch (e) {
    return false;
  }
}