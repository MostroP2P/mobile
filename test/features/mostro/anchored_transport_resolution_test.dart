import 'dart:async';
import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/data/models/enums/storage_keys.dart';
import 'package:mostro_mobile/data/repositories/open_orders_repository.dart';
import 'package:mostro_mobile/features/mostro/protocol_version_store.dart';
import 'package:mostro_mobile/features/mostro/transport.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../mocks.mocks.dart';

/// A kind-38385 info event shaped like mostrod's: empty content, everything in
/// tags. Passing null for [protocolVersion] omits the tag entirely, which is
/// what every daemon before v0.18.0 publishes.
NostrEvent _infoEvent(
  NostrKeyPairs keyPair, {
  required String? protocolVersion,
}) {
  return NostrEvent.fromPartialData(
    kind: 38385,
    content: '',
    keyPairs: keyPair,
    tags: [
      ['d', 'info'],
      ['y', 'mostro'],
      ['z', 'info'],
      if (protocolVersion != null) ['protocol_version', protocolVersion],
    ],
  );
}

class _FakeSharedPreferencesAsync implements SharedPreferencesAsync {
  final Map<String, String> strings = {};

  @override
  Future<String?> getString(String key) async => strings[key];

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

/// Reads [anchoredProtocolVersionFor] from inside the container. It takes a
/// `Ref`, which only a provider has; refresh this to re-evaluate it.
final _anchored = Provider<int?>((ref) => anchoredProtocolVersionFor(ref));

void main() {
  late MockNostrService mockNostrService;
  late StreamController<NostrEvent> eventController;
  late NostrKeyPairs nodeKeys;
  late _FakeSharedPreferencesAsync prefs;
  late ProviderContainer container;

  setUp(() async {
    nodeKeys = NostrUtils.generateKeyPair();
    mockNostrService = MockNostrService();
    eventController = StreamController<NostrEvent>.broadcast();

    final settings = Settings(
      relays: const ['wss://relay.example'],
      fullPrivacyMode: false,
      mostroPublicKey: nodeKeys.public,
    );

    prefs = _FakeSharedPreferencesAsync();
    prefs.strings[SharedPreferencesKeys.appSettings.value] =
        jsonEncode(settings.toJson());

    when(mockNostrService.isInitialized).thenReturn(true);
    when(mockNostrService.subscribeToEvents(any))
        .thenAnswer((_) => eventController.stream);

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        orderRepositoryProvider.overrideWithValue(
          OpenOrdersRepository(mockNostrService, settings),
        ),
      ],
    );

    await container.read(settingsProvider.notifier).init();
    expect(container.read(settingsProvider).mostroPublicKey, nodeKeys.public);
  });

  tearDown(() async {
    container.dispose();
    await eventController.close();
  });

  int? anchored() => container.refresh(_anchored);

  /// Feeds [event] through the repository and waits for it to be applied.
  Future<void> deliver(NostrEvent event) async {
    final applied = container
        .read(orderRepositoryProvider)
        .mostroInstanceStream
        .first
        .timeout(const Duration(seconds: 2));
    eventController.add(event);
    await applied;
  }

  // The `null` returned by NostrEventExtensions.protocolVersion means two
  // different things, and collapsing them is a self-inflicted partition: a
  // legacy node that publishes a perfectly valid info event without the tag
  // would resolve to kind 14 and never be heard from again, because it only
  // ever listens on kind 1059.
  group('a verified info event with no protocol_version tag', () {
    test('resolves to gift wrap, not to the safe default', () async {
      await deliver(_infoEvent(nodeKeys, protocolVersion: null));

      expect(anchored(), kLegacyProtocolVersion);
      expect(resolveTransport(anchored()), Transport.giftWrap);
    });

    test('is still distinct from having no info event at all', () {
      // Nothing delivered: absence of evidence, so the safe default stands.
      expect(anchored(), isNull);
      expect(resolveTransport(anchored()), kDefaultTransport);
    });

    test('does not walk back a node already verified at v2', () async {
      container.read(protocolVersionStoreProvider).record(nodeKeys.public, 2);

      await deliver(_infoEvent(nodeKeys, protocolVersion: null));

      // The ratchet outranks a tag-less event: on a node that has already
      // migrated, only a relay replaying an old event produces this state.
      expect(anchored(), 2);
      expect(resolveTransport(anchored()), Transport.nip44);
    });
  });

  group('a verified info event advertising a version', () {
    test('v2 resolves to nip44', () async {
      await deliver(_infoEvent(nodeKeys, protocolVersion: '2'));

      expect(anchored(), 2);
      expect(resolveTransport(anchored()), Transport.nip44);
    });

    test('an explicit v1 resolves to gift wrap', () async {
      await deliver(_infoEvent(nodeKeys, protocolVersion: '1'));

      expect(anchored(), 1);
      expect(resolveTransport(anchored()), Transport.giftWrap);
    });
  });

  // Three states, not two. `protocolVersion` returns null for an absent tag
  // and for an unusable one, and only the first is the node asserting v1.
  group('a malformed protocol_version tag', () {
    test('an unparseable value falls back to the safe default', () async {
      await deliver(_infoEvent(nodeKeys, protocolVersion: 'abc'));

      expect(anchored(), isNull);
      expect(resolveTransport(anchored()), kDefaultTransport);
    });

    test('an empty value falls back to the safe default', () async {
      await deliver(_infoEvent(nodeKeys, protocolVersion: ''));

      expect(anchored(), isNull);
      expect(resolveTransport(anchored()), kDefaultTransport);
    });

    test('does not lower a node already verified at v2', () async {
      container.read(protocolVersionStoreProvider).record(nodeKeys.public, 2);

      await deliver(_infoEvent(nodeKeys, protocolVersion: 'abc'));

      expect(anchored(), 2);
      expect(resolveTransport(anchored()), Transport.nip44);
    });

    test('a version this client does not speak is not read as legacy',
        () async {
      await deliver(_infoEvent(nodeKeys, protocolVersion: '99'));

      // Parseable, so it reaches resolveTransport, which degrades upwards.
      expect(anchored(), 99);
      expect(resolveTransport(anchored()), kDefaultTransport);
    });
  });
}
