import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/enums/storage_keys.dart';
import 'package:mostro_mobile/features/mostro/protocol_version_store.dart';
import 'package:mostro_mobile/features/mostro/transport.dart';
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


class _Countdown {
  int _micros;
  _Countdown(this._micros);

  Duration next() {
    final current = Duration(microseconds: _micros);
    _micros = _micros > 500 ? _micros - 500 : 0;
    return current;
  }
}

/// Completes its writes in reverse call order, so a store that fires them
/// concurrently loses the race and a store that queues them does not.
class _ReorderingSharedPreferencesAsync implements SharedPreferencesAsync {
  final Map<String, String> strings = {};

  /// Longest delay first: each successive call waits less than the one before
  /// it, so without serialisation the last call lands first. Held in a box
  /// because `SharedPreferencesAsync` is `@immutable`.
  final _Countdown _delay = _Countdown(5000);

  @override
  Future<String?> getString(String key) async => strings[key];

  @override
  Future<void> setString(String key, String value) async {
    await _stagger();
    strings[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    await _stagger();
    strings.remove(key);
  }

  Future<void> _stagger() => Future.delayed(_delay.next());

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// Delays only the read, so `init()` is still awaiting `_load()` while a
/// `record()` lands. Reproduces bootstrap order: `RelaysNotifier` builds a
/// `SubscriptionManager` — and with it the info-event feed into `record()` —
/// before `appInitializerProvider` gets to `init()`.
class _SlowReadSharedPreferencesAsync implements SharedPreferencesAsync {
  final Map<String, String> strings = {};

  @override
  Future<String?> getString(String key) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return strings[key];
  }

  @override
  Future<void> setString(String key, String value) async {
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

/// Three moments in a node's life, as info-event `created_at` seconds: the
/// last event before the operator migrated, the one announcing v2, and the one
/// announcing a rollback to v1.
const int _beforeMigration = 1000;
const int _migration = 2000;
const int _rollback = 3000;

DateTime _at(int seconds) =>
    DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);

/// The persisted shape of one entry.
Map<String, Object> _entry(int version, int seconds) => {
      'v': version,
      't': seconds,
    };

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
      expect(store.assertionFor(_nodeA), isNull);
    });

    test('records a version and reports it back', () {
      expect(store.record(_nodeA, 2, _at(_migration)), isTrue);
      expect(store.versionFor(_nodeA), 2);
    });

    test('reports the date the version was asserted', () {
      store.record(_nodeA, 2, _at(_migration));

      expect(
        store.assertionFor(_nodeA),
        VersionAssertion(2, _at(_migration)),
      );
    });

    test('keeps each node separate', () {
      store.record(_nodeA, 2, _at(_migration));
      store.record(_nodeB, 1, _at(_beforeMigration));

      expect(store.versionFor(_nodeA), 2);
      expect(store.versionFor(_nodeB), 1);
    });

    test('ignores an empty pubkey', () {
      expect(store.record('', 2, _at(_migration)), isFalse);
    });

    test('ignores a non-positive version', () {
      expect(store.record(_nodeA, 0, _at(_migration)), isFalse);
      expect(store.record(_nodeA, -1, _at(_migration)), isFalse);
      expect(store.versionFor(_nodeA), isNull);
    });
  });

  group('ProtocolVersionStore anchor', () {
    // The whole point of the store: a relay can pick which signed events it
    // serves, but it cannot mint one or move one forward in time, so an
    // assertion older than the newest verified one is never accepted.
    test('refuses an assertion older than the one it holds', () {
      store.record(_nodeA, 2, _at(_migration));

      expect(store.record(_nodeA, 1, _at(_beforeMigration)), isFalse);
      expect(store.versionFor(_nodeA), 2);
    });

    // The case the anchor is dated for, and the one a purely monotonic ratchet
    // gets wrong: mostrod 0.18.x still ships gift-wrap, so an operator undoing
    // a bad v2 rollout signs a newer v1 assertion. Refusing it would partition
    // this client from the node until the app was reinstalled.
    test('follows a newer v1 assertion after a recorded v2', () {
      store.record(_nodeA, 2, _at(_migration));

      expect(store.record(_nodeA, 1, _at(_rollback)), isTrue);
      expect(store.versionFor(_nodeA), 1);
    });

    test('raises a recorded version', () {
      store.record(_nodeA, 1, _at(_beforeMigration));

      expect(store.record(_nodeA, 2, _at(_migration)), isTrue);
      expect(store.versionFor(_nodeA), 2);
    });

    test('re-recording the same assertion is a no-op', () {
      store.record(_nodeA, 2, _at(_migration));

      expect(store.record(_nodeA, 2, _at(_migration)), isFalse);
      expect(store.versionFor(_nodeA), 2);
    });

    // The date is what later replays are measured against, so a re-assertion
    // of the same version has to move it forward.
    test('a newer assertion of the same version advances the date', () {
      store.record(_nodeA, 2, _at(_migration));

      expect(store.record(_nodeA, 2, _at(_rollback)), isTrue);
      expect(store.assertionFor(_nodeA)?.createdAt, _at(_rollback));
    });

    // Freshness cannot separate same-second assertions, so the safer transport
    // wins rather than whichever relay answered first.
    test('a same-second downgrade loses to the recorded version', () {
      store.record(_nodeA, 2, _at(_migration));

      expect(store.record(_nodeA, 1, _at(_migration)), isFalse);
      expect(store.versionFor(_nodeA), 2);
    });

    test('an undated assertion cannot lower a dated one', () {
      store.record(_nodeA, 2, _at(_migration));

      expect(store.record(_nodeA, 1, null), isFalse);
      expect(store.versionFor(_nodeA), 2);
    });

    test('a downgrade attempt on one node does not touch another', () {
      store.record(_nodeA, 2, _at(_migration));
      store.record(_nodeB, 2, _at(_migration));

      store.record(_nodeA, 1, _at(_beforeMigration));

      expect(store.versionFor(_nodeA), 2);
      expect(store.versionFor(_nodeB), 2);
    });
  });

  group('ProtocolVersionStore persistence', () {
    test('survives a restart', () async {
      store.record(_nodeA, 2, _at(_migration));
      await store.pendingWrites;

      final reopened = ProtocolVersionStore(prefs);
      await reopened.init();

      expect(reopened.versionFor(_nodeA), 2);
    });

    test('the date survives a restart too', () async {
      store.record(_nodeA, 2, _at(_migration));
      await store.pendingWrites;

      final reopened = ProtocolVersionStore(prefs);
      await reopened.init();

      // Without it, the anchor after a restart could only compare versions —
      // exactly the monotonic behaviour this store moved away from.
      expect(reopened.assertionFor(_nodeA)?.createdAt, _at(_migration));
      expect(reopened.record(_nodeA, 1, _at(_rollback)), isTrue);
    });

    test('the anchor holds across a restart', () async {
      store.record(_nodeA, 2, _at(_migration));
      await store.pendingWrites;

      final reopened = ProtocolVersionStore(prefs);
      await reopened.init();

      expect(reopened.record(_nodeA, 1, _at(_beforeMigration)), isFalse);
      expect(reopened.versionFor(_nodeA), 2);
    });

    test('writes the whole snapshot, not just the last change', () async {
      store.record(_nodeA, 2, _at(_migration));
      store.record(_nodeB, 1, _at(_beforeMigration));
      await store.pendingWrites;

      expect(
        jsonDecode(prefs.strings[_key]!),
        {
          _nodeA: _entry(2, _migration),
          _nodeB: _entry(1, _beforeMigration),
        },
      );
    });

    test('an undated assertion persists without a date', () async {
      store.record(_nodeA, 2, null);
      await store.pendingWrites;

      expect(jsonDecode(prefs.strings[_key]!), {
        _nodeA: {'v': 2},
      });
    });

    test('a failed write leaves memory authoritative', () async {
      final failing = _FakeSharedPreferencesAsync(failWrites: true);
      final s = ProtocolVersionStore(failing);
      await s.init();

      expect(s.record(_nodeA, 2, _at(_migration)), isTrue);
      expect(s.versionFor(_nodeA), 2);
    });

    test('clear forgets everything', () async {
      store.record(_nodeA, 2, _at(_migration));
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

    // A single bad entry must not cost the anchor its memory of every other
    // node — that would be a downgrade window opened by a storage bug.
    test('drops malformed entries but keeps the good ones', () async {
      final s = await storeWith(jsonEncode({
        _nodeA: _entry(2, _migration),
        _nodeB: 'garbage',
        'another': null,
        'negative': _entry(-5, _migration),
        // The pre-dated shape, from a build before the anchor carried a date.
        // An entry that cannot be dated cannot be weighed against a signed
        // event, so it is not evidence and is dropped like any other.
        'undatable': 2,
      }));

      expect(s.versionFor(_nodeA), 2);
      expect(s.versionFor(_nodeB), isNull);
      expect(s.versionFor('another'), isNull);
      expect(s.versionFor('negative'), isNull);
      expect(s.versionFor('undatable'), isNull);
    });

    test('accepts numeric strings for both fields', () async {
      final s = await storeWith(jsonEncode({
        _nodeA: {'v': '2', 't': '$_migration'},
      }));

      expect(s.assertionFor(_nodeA), VersionAssertion(2, _at(_migration)));
    });

    test('keeps an entry whose date is missing or unusable', () async {
      final s = await storeWith(jsonEncode({
        _nodeA: {'v': 2},
        _nodeB: {'v': 2, 't': 'whenever'},
      }));

      // The version is still evidence, it just cannot be ranked by freshness;
      // the anchor falls back to refusing anything lower.
      expect(s.assertionFor(_nodeA), const VersionAssertion(2, null));
      expect(s.assertionFor(_nodeB), const VersionAssertion(2, null));
      expect(s.record(_nodeA, 1, _at(_rollback)), isFalse);
    });
  });

  group('ProtocolVersionStore write ordering', () {
    late _ReorderingSharedPreferencesAsync slowPrefs;
    late ProtocolVersionStore orderedStore;

    setUp(() async {
      slowPrefs = _ReorderingSharedPreferencesAsync();
      orderedStore = ProtocolVersionStore(slowPrefs);
      await orderedStore.init();
    });

    test('the newest snapshot is the one that lands', () async {
      orderedStore.record(_nodeA, 1, _at(_beforeMigration));
      orderedStore.record(_nodeA, 2, _at(_migration));
      await orderedStore.pendingWrites;

      // Unserialised, the second (faster) write would land first and the first
      // would overwrite it with the stale v1 entry.
      expect(
        jsonDecode(slowPrefs.strings[_key]!),
        {_nodeA: _entry(2, _migration)},
      );
    });

    test('a write issued before clear() does not resurrect the map', () async {
      orderedStore.record(_nodeA, 2, _at(_migration));
      await orderedStore.clear();

      expect(slowPrefs.strings[_key], isNull);
      expect(orderedStore.versionFor(_nodeA), isNull);
    });
  });
  group('ProtocolVersionStore records arriving before init', () {
    late _SlowReadSharedPreferencesAsync slowRead;
    late ProtocolVersionStore earlyStore;

    setUp(() {
      slowRead = _SlowReadSharedPreferencesAsync();
      earlyStore = ProtocolVersionStore(slowRead);
    });

    test('a version recorded while loading is not dropped', () async {
      final loading = earlyStore.init();
      earlyStore.record(_nodeA, 2, _at(_migration));
      await loading;

      expect(earlyStore.versionFor(_nodeA), 2);
    });

    test('and reaches disk instead of being erased by the next snapshot',
        () async {
      final loading = earlyStore.init();
      earlyStore.record(_nodeA, 2, _at(_migration));
      await loading;

      // A later record for a different node snapshots the whole map. If init()
      // had dropped _nodeA, this write is what would carry the loss to disk.
      earlyStore.record(_nodeB, 2, _at(_migration));
      await earlyStore.pendingWrites;

      expect(
        jsonDecode(slowRead.strings[_key]!),
        {_nodeA: _entry(2, _migration), _nodeB: _entry(2, _migration)},
      );
    });

    test('the persisted assertion wins when it is the more recent one',
        () async {
      slowRead.strings[_key] = jsonEncode({_nodeA: _entry(2, _migration)});

      final loading = earlyStore.init();
      // A replayed pre-migration event racing the load must not lower the
      // anchor once the load catches up with it.
      earlyStore.record(_nodeA, 1, _at(_beforeMigration));
      await loading;

      expect(earlyStore.versionFor(_nodeA), 2);
    });

    test('an early record still wins when it is the more recent one', () async {
      slowRead.strings[_key] = jsonEncode({_nodeA: _entry(2, _migration)});

      final loading = earlyStore.init();
      earlyStore.record(_nodeA, 1, _at(_rollback));
      await loading;

      expect(earlyStore.versionFor(_nodeA), 1);
    });

    test('an early record for an unrelated node keeps the loaded ones',
        () async {
      slowRead.strings[_key] = jsonEncode({_nodeB: _entry(2, _migration)});

      final loading = earlyStore.init();
      earlyStore.record(_nodeA, 2, _at(_migration));
      await loading;

      expect(earlyStore.versionFor(_nodeA), 2);
      expect(earlyStore.versionFor(_nodeB), 2);
    });

    test('a record before init does not erase an earlier session', () async {
      slowRead.strings[_key] = jsonEncode({_nodeB: _entry(2, _migration)});

      // Bootstrap at its worst: the info event lands before init() is even
      // called. A snapshot of the still-empty map would overwrite _nodeB.
      earlyStore.record(_nodeA, 2, _at(_migration));
      await earlyStore.pendingWrites;
      expect(
        jsonDecode(slowRead.strings[_key]!),
        {_nodeB: _entry(2, _migration)},
      );

      await earlyStore.init();
      await earlyStore.pendingWrites;

      expect(
        jsonDecode(slowRead.strings[_key]!),
        {_nodeB: _entry(2, _migration), _nodeA: _entry(2, _migration)},
      );
      expect(earlyStore.versionFor(_nodeB), 2);
    });

    test('a plain cold start writes nothing', () async {
      await earlyStore.init();
      await earlyStore.pendingWrites;

      expect(slowRead.strings[_key], isNull);
    });
  });

}
