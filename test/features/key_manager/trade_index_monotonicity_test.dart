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

void main() {
  late _FakeKeyStorage storage;
  late KeyManager keyManager;

  setUp(() {
    storage = _FakeKeyStorage();
    keyManager = KeyManager(storage, KeyDerivator("m/44'/1237'/38383'/0"));
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
}
