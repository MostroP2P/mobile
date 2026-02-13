import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/enums/storage_keys.dart';
import 'package:mostro_mobile/data/repositories/nwc_storage.dart';

void main() {
  late NwcStorage storage;
  late _FakeSecureStorage fakeSecure;

  setUp(() {
    fakeSecure = _FakeSecureStorage();
    storage = NwcStorage(secureStorage: fakeSecure);
  });

  group('NwcStorage', () {
    const testUri =
        'nostr+walletconnect://abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234?relay=wss://relay.example.com&secret=ef01ef01ef01ef01ef01ef01ef01ef01ef01ef01ef01ef01ef01ef01ef01ef01';

    test('saveConnection stores URI', () async {
      await storage.saveConnection(testUri);
      expect(
        fakeSecure.store[SecureStorageKeys.nwcConnectionUri.value],
        testUri,
      );
    });

    test('readConnection returns stored URI', () async {
      await storage.saveConnection(testUri);
      final result = await storage.readConnection();
      expect(result, testUri);
    });

    test('readConnection returns null when empty', () async {
      final result = await storage.readConnection();
      expect(result, isNull);
    });

    test('deleteConnection removes URI', () async {
      await storage.saveConnection(testUri);
      await storage.deleteConnection();
      final result = await storage.readConnection();
      expect(result, isNull);
    });

    test('hasConnection returns true when URI exists', () async {
      await storage.saveConnection(testUri);
      expect(await storage.hasConnection(), isTrue);
    });

    test('hasConnection returns false when no URI', () async {
      expect(await storage.hasConnection(), isFalse);
    });
  });
}

/// Simple fake for FlutterSecureStorage to avoid platform dependencies.
class _FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> store = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      store[key] = value;
    } else {
      store.remove(key);
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return store[key];
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    store.remove(key);
  }
}
