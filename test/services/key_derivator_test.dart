import 'package:test/test.dart';
import 'package:mostro_mobile/features/key_manager/key_derivator.dart';

/// Test vectors from NIP-06
/// https://github.com/nostr-protocol/nips/blob/master/06.md

void main() {
  group('KeyDerivator (NIP-06) Tests', () {
    const derivationPath = "m/44'/1237'/0'/0";
    test('Test Vector 1: leader monkey parrot ring guide accident ...', () {
      const mnemonic =
          'leader monkey parrot ring guide accident before fence cannon height naive bean';
      const expectedPrivateHex =
          '7f7ff03d123792d6ac594bfa67bf6d0c0ab55b6b1fdb6249303fe861f1ccba9a';
      const expectedPublicHex =
          '17162c921dc4d2518f9a101db33695df1afb56ab82f5ff3e5da6eec3ca5cd917';
      final keyDerivator = KeyDerivator(derivationPath);

      expect(keyDerivator.isMnemonicValid(mnemonic), isTrue);

      final derivedMaster = keyDerivator.masterPrivateKeyFromMnemonic(mnemonic);
      expect(derivedMaster, equals(expectedPrivateHex));

      final computedPub = keyDerivator.privateToPublicKey(derivedMaster);
      expect(computedPub, equals(expectedPublicHex));
    });

    test('Test Vector 2: what bleak badge arrange retreat wolf trade ...', () {
      const mnemonic =
          'what bleak badge arrange retreat wolf trade produce cricket blur garlic valid proud rude strong choose busy staff weather area salt hollow arm fade';
      const expectedPrivateHex =
          'c15d739894c81a2fcfd3a2df85a0d2c0dbc47a280d092799f144d73d7ae78add';
      const expectedPublicHex =
          'd41b22899549e1f3d335a31002cfd382174006e166d3e658e3a5eecdb6463573';
      final keyDerivator = KeyDerivator(derivationPath);

      expect(keyDerivator.isMnemonicValid(mnemonic), isTrue);

      final derivedMaster = keyDerivator.masterPrivateKeyFromMnemonic(mnemonic);
      expect(derivedMaster, equals(expectedPrivateHex));

      final computedPub = keyDerivator.privateToPublicKey(derivedMaster);
      expect(computedPub, equals(expectedPublicHex));
    });

    test('Random mnemonic is valid', () {
      final keyDerivator = KeyDerivator(derivationPath);
      final mnemonic = keyDerivator.generateMnemonic();
      expect(keyDerivator.isMnemonicValid(mnemonic), isTrue);
    });

    test('Derive child key from an example master key', () {
      const mnemonic =
          'leader monkey parrot ring guide accident before fence cannon height naive bean';
      const expectedPrivateHex =
          '7f7ff03d123792d6ac594bfa67bf6d0c0ab55b6b1fdb6249303fe861f1ccba9a';
      final keyDerivator = KeyDerivator(derivationPath);
      final masterKeyHex = keyDerivator.extendedKeyFromMnemonic(mnemonic);
      final childKeyHex = keyDerivator.derivePrivateKey(masterKeyHex, 0);

      expect(childKeyHex.length, equals(64));
      expect(childKeyHex, equals(expectedPrivateHex));
    });
  });

  group('Key derivation tests for Mostro', () {});
}
