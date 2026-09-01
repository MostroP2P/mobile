import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/features/key_manager/key_derivator.dart';
import 'package:mostro_mobile/features/key_manager/key_manager.dart';
import 'package:mostro_mobile/features/key_manager/key_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Decoding a session used to re-run the whole trade-key derivation —
/// BIP32.fromBase58 (base58check) + 5 CKD levels + an EC multiplication for
/// the pubkey — per session, at startup and again on every 30-minute
/// cleanup. Derivation is deterministic per (master key, index), so the
/// derived pairs are now memoized.
void main() {
  // Public NIP-06 test vector, same as key_derivator_test.dart.
  const mnemonicA =
      'leader monkey parrot ring guide accident before fence cannon height naive bean';
  const mnemonicB =
      'what bleak badge arrange retreat wolf trade produce cricket blur garlic valid proud rude strong choose busy staff weather area salt hollow arm fade';
  const derivationPath = "m/44'/1237'/38383'/0";

  late KeyDerivator derivator;
  late KeyManager manager;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    derivator = KeyDerivator(derivationPath);
    manager = KeyManager(
      KeyStorage(
        secureStorage: const FlutterSecureStorage(),
        sharedPrefs: SharedPreferencesAsync(),
      ),
      derivator,
    );
    manager.debugSetMasterKey(derivator.extendedKeyFromMnemonic(mnemonicA));
  });

  test('deriveTradeKeyPair memoizes per index', () {
    final first = manager.deriveTradeKeyPair(1);
    final second = manager.deriveTradeKeyPair(1);

    expect(identical(first, second), isTrue,
        reason: 'the same index must not repeat CKD + EC multiplication');
  });

  test('different indices derive different keys', () {
    expect(
      manager.deriveTradeKeyPair(1).private,
      isNot(manager.deriveTradeKeyPair(2).private),
    );
  });

  test('changing the master key invalidates the memo', () {
    final before = manager.deriveTradeKeyPair(1);

    manager.debugSetMasterKey(derivator.extendedKeyFromMnemonic(mnemonicB));
    final after = manager.deriveTradeKeyPair(1);

    expect(before.private, isNot(after.private));
  });

  test('derivation stays correct through the derivator root cache', () {
    final xprv = derivator.extendedKeyFromMnemonic(mnemonicA);

    final direct = derivator.derivePrivateKey(xprv, 7);
    final cached = derivator.derivePrivateKey(xprv, 7);

    expect(cached, direct);
    expect(derivator.privateToPublicKey(cached),
        derivator.privateToPublicKey(direct));
  });

  test('getNextKeyIndex reserves an index that deriveTradeKey cannot reuse',
      () async {
    // Arrange: the counter points at the next index to hand out.
    await manager.setCurrentKeyIndex(5);

    // Act: reserve an index for a range order's child session, then derive
    // the trade key for the next order the user creates or takes.
    final reserved = await manager.getNextKeyIndex();
    final reservedKey = await manager.deriveTradeKeyFromIndex(reserved);
    final nextKey = await manager.deriveTradeKey();

    // Assert: reusing the reserved index would give two live sessions the
    // same trade key, and with a shared counterparty the same ECDH shared
    // key — i.e. one conversation surfacing as two chats.
    expect(reserved, 5, reason: 'reserves the index deriveTradeKey was on');
    expect(reservedKey.public, isNot(nextKey.public));
    expect(await manager.getCurrentKeyIndex(), 7,
        reason: 'both handed-out indices are consumed, leaving no gap');
  });
}
