import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/last_trade_index_response.dart';
import 'package:mostro_mobile/features/key_manager/key_derivator.dart';
import 'package:mostro_mobile/features/key_manager/key_manager.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_errors.dart';
import 'package:mostro_mobile/features/key_manager/key_storage.dart';

/// Only the two index methods are exercised here; anything else is a bug in
/// the test, not a case to stub out.
class _FakeKeyStorage implements KeyStorage {
  int index = 1;

  /// A real extended key, derived from a fixed mnemonic in [setUp]. The
  /// derivator takes a BIP32 xprv, not a raw private key.
  String? masterKey;

  @override
  Future<String?> readMasterKey() async => masterKey;

  @override
  Future<int> readTradeKeyIndex() async => index;

  @override
  Future<void> storeTradeKeyIndex(int value) async {
    index = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// A fixed BIP39 mnemonic, so every derivation here is reproducible.
const _mnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon about';

void main() {
  late _FakeKeyStorage storage;
  late KeyManager keyManager;

  late KeyDerivator derivator;

  setUp(() {
    derivator = KeyDerivator("m/44'/1237'/38383'/0");
    storage = _FakeKeyStorage();
    storage.masterKey = derivator.extendedKeyFromMnemonic(_mnemonic);
    keyManager = KeyManager(storage, derivator);
  });

  // MM-021 / MM-003: the index counts trade keys this device has derived.
  // Lowering it reissues keys that have already been used — past and future
  // trades become linkable by a shared pubkey, and a live session can find its
  // key handed out again underneath it.
  group('raiseCurrentKeyIndexTo', () {
    test('raises to a higher index', () async {
      storage.index = 10;

      expect(await keyManager.raiseCurrentKeyIndexTo(51), 51);
      expect(await keyManager.getCurrentKeyIndex(), 51);
    });

    test('refuses to lower the index', () async {
      storage.index = 50;

      expect(await keyManager.raiseCurrentKeyIndexTo(11), 50);
      expect(await keyManager.getCurrentKeyIndex(), 50);
    });

    test('an equal index is a no-op', () async {
      storage.index = 50;

      expect(await keyManager.raiseCurrentKeyIndexTo(50), 50);
      expect(await keyManager.getCurrentKeyIndex(), 50);
    });

    test('rejects a non-positive index', () async {
      await expectLater(
        keyManager.raiseCurrentKeyIndexTo(0),
        throwsA(isA<InvalidTradeKeyIndexException>()),
      );
    });

    // Not only an attack: the daemon only knows indexes that reached an order,
    // so a device that derived keys without trading is legitimately ahead.
    test('a device ahead of the daemon keeps its position', () async {
      storage.index = 50;

      await keyManager.raiseCurrentKeyIndexTo(20 + 1);

      expect(await keyManager.getCurrentKeyIndex(), 50);
    });
  });

  group('LastTradeIndexResponse parsing', () {
    test('accepts a valid index', () {
      expect(
        LastTradeIndexResponse.fromJson({'trade_index': 42}).tradeIndex,
        42,
      );
    });

    test('accepts zero, meaning no trades yet', () {
      expect(
        LastTradeIndexResponse.fromJson({'trade_index': 0}).tradeIndex,
        0,
      );
    });

    test('rejects a negative index', () {
      expect(
        () => LastTradeIndexResponse.fromJson({'trade_index': -5}),
        throwsFormatException,
      );
    });

    test('rejects a missing index', () {
      expect(
        () => LastTradeIndexResponse.fromJson(const {}),
        throwsFormatException,
      );
    });

    test('rejects a non-numeric index', () {
      expect(
        () => LastTradeIndexResponse.fromJson({'trade_index': 'many'}),
        throwsFormatException,
      );
    });
  });
  // MM-003: index 0 is the identity key — `_getMasterKey` derives it — so a
  // "trade key 0" is the master identity. The restore path derives straight
  // from an index in the daemon's response, without going through the counter
  // that has always refused it.
  group('trade key index bounds', () {
    setUp(() async {
      await keyManager.init();
    });

    test('index 0 is the identity key, not a trade key', () {
      // What the guard keeps out of a session: index 0 is what
      // KeyManager.masterKeyPair is derived from, so a session built on
      // "trade key 0" would sign and ECDH under the master identity.
      final atZero = derivator.derivePrivateKey(storage.masterKey!, 0);

      expect(atZero, keyManager.masterKeyPair!.private);
      expect(atZero, isNot(derivator.derivePrivateKey(storage.masterKey!, 1)));
    });

    test('deriveTradeKeyPair refuses index 0', () {
      expect(
        () => keyManager.deriveTradeKeyPair(0),
        throwsA(isA<InvalidTradeKeyIndexException>()),
      );
    });

    test('deriveTradeKeyPair refuses a negative index', () {
      expect(
        () => keyManager.deriveTradeKeyPair(-1),
        throwsA(isA<InvalidTradeKeyIndexException>()),
      );
    });

    test('deriveTradeKeyPair still derives a real trade key', () {
      expect(keyManager.deriveTradeKeyPair(1), isA<NostrKeyPairs>());
      expect(keyManager.deriveTradeKeyPair(9999), isA<NostrKeyPairs>());
    });

    test('deriveTradeKeyFromIndex refuses index 0', () async {
      await expectLater(
        keyManager.deriveTradeKeyFromIndex(0),
        throwsA(isA<InvalidTradeKeyIndexException>()),
      );
    });

    test('deriveTradeKeyFromIndex refuses before it reads the master key',
        () async {
      // The argument is wrong whatever storage holds, and saying so without
      // touching the key keeps the two failures apart.
      storage.masterKey = null;

      await expectLater(
        keyManager.deriveTradeKeyFromIndex(0),
        throwsA(isA<InvalidTradeKeyIndexException>()),
      );
    });

    test('deriveTradeKeyFromIndex still derives a real trade key', () async {
      expect(await keyManager.deriveTradeKeyFromIndex(1), isA<NostrKeyPairs>());
    });
  });
}
