import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/enums/storage_keys.dart';
import 'package:mostro_mobile/features/mostro/protocol_version_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal in-memory double for the three methods the store uses.
class _FakeSharedPreferencesAsync implements SharedPreferencesAsync {
  final Map<String, String> strings = {};

  /// When set, every write fails — used to prove memory stays authoritative.
  final bool failWrites;

  _FakeSharedPreferencesAsync({this.failWrites = false});

  @override
  Future<String?> getString(String key) async => strings[key];

  @override
  Future<void> setString(String key, String value) async {
    if (failWrites) throw Exception('disk full');
    strings[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    strings.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

const _nodeA =
    '9d9d0455a96871f2dc4289b8312429db2e925f167b37c77bf7b28014be235980';
const _nodeB =
    '0000000000000000000000000000000000000000000000000000000000000001';

final _key = SharedPreferencesKeys.nodeProtocolVersions.value;

void main() {
  late _FakeSharedPreferencesAsync prefs;
  late ProtocolVersionStore store;

  setUp(() async {
    prefs = _FakeSharedPreferencesAsync();
    store = ProtocolVersionStore(prefs);
    await store.init();
  });

  group('ProtocolVersionStore basics', () {
    test('knows nothing about a node it has never seen', () {
      expect(store.versionFor(_nodeA), isNull);
    });

    test('records a version and reports it back', () {
      expect(store.record(_nodeA, 2), isTrue);
      expect(store.versionFor(_nodeA), 2);
    });

    test('keeps each node separate', () {
      store.record(_nodeA, 2);
      store.record(_nodeB, 1);

      expect(store.versionFor(_nodeA), 2);
      expect(store.versionFor(_nodeB), 1);
    });

    test('ignores an empty pubkey', () {
      expect(store.record('', 2), isFalse);
    });

    test('ignores a non-positive version', () {
      expect(store.record(_nodeA, 0), isFalse);
      expect(store.record(_nodeA, -1), isFalse);
      expect(store.versionFor(_nodeA), isNull);
    });
  });

  group('ProtocolVersionStore ratchet', () {
    // The whole point of the store: once a node has been verified speaking v2,
    // nothing can make this client speak v1 to it again.
    test('never lowers a recorded version', () {
      store.record(_nodeA, 2);

      expect(store.record(_nodeA, 1), isFalse);
      expect(store.versionFor(_nodeA), 2);
    });

    test('raises a recorded version', () {
      store.record(_nodeA, 1);

      expect(store.record(_nodeA, 2), isTrue);
      expect(store.versionFor(_nodeA), 2);
    });

    test('re-recording the same version is a no-op', () {
      store.record(_nodeA, 2);

      expect(store.record(_nodeA, 2), isFalse);
      expect(store.versionFor(_nodeA), 2);
    });

    test('a downgrade attempt on one node does not touch another', () {
      store.record(_nodeA, 2);
      store.record(_nodeB, 2);

      store.record(_nodeA, 1);

      expect(store.versionFor(_nodeA), 2);
      expect(store.versionFor(_nodeB), 2);
    });
  });

  group('ProtocolVersionStore persistence', () {
    test('survives a restart', () async {
      store.record(_nodeA, 2);

      final reopened = ProtocolVersionStore(prefs);
      await reopened.init();

      expect(reopened.versionFor(_nodeA), 2);
    });

    test('the ratchet holds across a restart', () async {
      store.record(_nodeA, 2);

      final reopened = ProtocolVersionStore(prefs);
      await reopened.init();

      expect(reopened.record(_nodeA, 1), isFalse);
      expect(reopened.versionFor(_nodeA), 2);
    });

    test('writes the whole snapshot, not just the last change', () async {
      store.record(_nodeA, 2);
      store.record(_nodeB, 1);

      expect(
        jsonDecode(prefs.strings[_key]!),
        {_nodeA: 2, _nodeB: 1},
      );
    });

    test('a failed write leaves memory authoritative', () async {
      final failing = _FakeSharedPreferencesAsync(failWrites: true);
      final s = ProtocolVersionStore(failing);
      await s.init();

      expect(s.record(_nodeA, 2), isTrue);
      expect(s.versionFor(_nodeA), 2);
    });

    test('clear forgets everything', () async {
      store.record(_nodeA, 2);
      await store.clear();

      expect(store.versionFor(_nodeA), isNull);
      expect(prefs.strings[_key], isNull);
    });
  });

  group('ProtocolVersionStore corrupt storage', () {
    Future<ProtocolVersionStore> storeWith(String raw) async {
      prefs.strings[_key] = raw;
      final s = ProtocolVersionStore(prefs);
      await s.init();
      return s;
    }

    test('starts empty on unparseable JSON', () async {
      final s = await storeWith('{not json');
      expect(s.versionFor(_nodeA), isNull);
      expect(s.isInitialized, isTrue);
    });

    test('starts empty when the payload is not a map', () async {
      final s = await storeWith('[1, 2, 3]');
      expect(s.versionFor(_nodeA), isNull);
    });

    // A single bad entry must not cost the ratchet its memory of every other
    // node — that would be a downgrade window opened by a storage bug.
    test('drops malformed entries but keeps the good ones', () async {
      final s = await storeWith(jsonEncode({
        _nodeA: 2,
        _nodeB: 'garbage',
        'another': null,
        'negative': -5,
      }));

      expect(s.versionFor(_nodeA), 2);
      expect(s.versionFor(_nodeB), isNull);
      expect(s.versionFor('another'), isNull);
      expect(s.versionFor('negative'), isNull);
    });

    test('accepts a numeric string version', () async {
      final s = await storeWith(jsonEncode({_nodeA: '2'}));
      expect(s.versionFor(_nodeA), 2);
    });
  });
}
