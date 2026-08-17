import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/core/models/relay_list_event.dart';
import 'package:mostro_mobile/features/relays/relay.dart';

final _publishedAt = DateTime.utc(2026, 1, 1);
final _authorPubkey = 'a' * 64;

NostrEvent relayListEvent({
  int kind = 10002,
  List<List<String>>? tags,
  DateTime? createdAt,
  String? pubkey,
}) =>
    NostrEvent(
      id: 'event-id',
      kind: kind,
      content: '',
      sig: 'sig',
      pubkey: pubkey ?? _authorPubkey,
      createdAt: createdAt ?? _publishedAt,
      tags: tags ??
          const [
            ['r', 'wss://relay.one'],
            ['r', 'wss://relay.two'],
          ],
    );

RelayListEvent relayList(List<String> relays, {String author = 'author'}) =>
    RelayListEvent(
      relays: relays,
      publishedAt: _publishedAt,
      authorPubkey: author,
    );

void main() {
  group('Relay', () {
    test('defaults to a healthy user relay', () {
      final relay = Relay(url: 'wss://relay.example');

      expect(relay.isHealthy, isTrue);
      expect(relay.source, RelaySource.user);
      expect(relay.addedAt, isNull);
    });

    test('fromMostro tags the relay as auto-discovered', () {
      final relay = Relay.fromMostro('wss://relay.mostro');

      expect(relay.source, RelaySource.mostro);
      expect(relay.isHealthy, isTrue);
      expect(relay.addedAt, isNotNull);
      expect(relay.isAutoDiscovered, isTrue);
    });

    test('fromDefault tags the relay as default config', () {
      final relay = Relay.fromDefault('wss://relay.default');

      expect(relay.source, RelaySource.defaultConfig);
      expect(relay.isAutoDiscovered, isTrue);
      expect(relay.addedAt, isNotNull);
    });

    test('only user relays can be deleted', () {
      expect(Relay(url: 'wss://a').canDelete, isTrue);
      expect(Relay.fromMostro('wss://a').canDelete, isFalse);
      expect(Relay.fromDefault('wss://a').canDelete, isFalse);
    });

    test('only auto-discovered relays can be blacklisted', () {
      expect(Relay(url: 'wss://a').canBlacklist, isFalse);
      expect(Relay.fromMostro('wss://a').canBlacklist, isTrue);
      expect(Relay.fromDefault('wss://a').canBlacklist, isTrue);
    });

    test('user relays are not auto-discovered', () {
      expect(Relay(url: 'wss://a').isAutoDiscovered, isFalse);
    });

    test('copyWith overrides only the requested fields', () {
      final original = Relay(
        url: 'wss://a',
        isHealthy: true,
        source: RelaySource.mostro,
        addedAt: DateTime.utc(2026),
      );

      final copy = original.copyWith(isHealthy: false);

      expect(copy.url, 'wss://a');
      expect(copy.isHealthy, isFalse);
      expect(copy.source, RelaySource.mostro);
      expect(copy.addedAt, DateTime.utc(2026));
    });

    test('copyWith can override every field', () {
      final copy = Relay(url: 'wss://a').copyWith(
        url: 'wss://b',
        isHealthy: false,
        source: RelaySource.defaultConfig,
        addedAt: DateTime.utc(2030),
      );

      expect(copy.url, 'wss://b');
      expect(copy.isHealthy, isFalse);
      expect(copy.source, RelaySource.defaultConfig);
      expect(copy.addedAt, DateTime.utc(2030));
    });

    test('survives a JSON round trip', () {
      final original = Relay(
        url: 'wss://a',
        isHealthy: false,
        source: RelaySource.mostro,
        addedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );

      final restored = Relay.fromJson(original.toJson());

      expect(restored.url, original.url);
      expect(restored.isHealthy, original.isHealthy);
      expect(restored.source, original.source);
      expect(restored.addedAt, original.addedAt);
    });

    test('serialises the source by name and addedAt as epoch millis', () {
      final json = Relay(
        url: 'wss://a',
        source: RelaySource.defaultConfig,
        addedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      ).toJson();

      expect(json['source'], 'defaultConfig');
      expect(json['addedAt'], 1700000000000);
    });

    test('serialises a null addedAt as null', () {
      expect(Relay(url: 'wss://a').toJson()['addedAt'], isNull);
    });

    test('fromJson falls back to an unhealthy user relay', () {
      final relay = Relay.fromJson(const {'url': 'wss://a'});

      expect(relay.isHealthy, isFalse);
      expect(relay.source, RelaySource.user);
      expect(relay.addedAt, isNull);
    });

    test('fromJson falls back to user for an unknown source', () {
      final relay =
          Relay.fromJson(const {'url': 'wss://a', 'source': 'martian'});

      expect(relay.source, RelaySource.user);
    });

    test('compares by url only', () {
      final a = Relay(url: 'wss://same', isHealthy: true);
      final b = Relay(
        url: 'wss://same',
        isHealthy: false,
        source: RelaySource.mostro,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(Relay(url: 'wss://other')));
      expect(a, equals(a));
    });

    test('renders url, health and source', () {
      final relay = Relay(url: 'wss://a', source: RelaySource.mostro);

      expect(relay.toString(),
          'Relay(url: wss://a, healthy: true, source: RelaySource.mostro)');
    });
  });

  group('MostroRelayInfo', () {
    test('compares by url only', () {
      final a =
          MostroRelayInfo(url: 'wss://a', isActive: true, isHealthy: true);
      final b = MostroRelayInfo(
        url: 'wss://a',
        isActive: false,
        isHealthy: false,
        source: RelaySource.mostro,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(MostroRelayInfo(url: 'wss://b', isActive: true, isHealthy: true)),
      );
      expect(a, equals(a));
    });

    test('keeps the optional source null by default', () {
      final info =
          MostroRelayInfo(url: 'wss://a', isActive: true, isHealthy: true);

      expect(info.source, isNull);
      expect(info.toString(),
          'MostroRelayInfo(url: wss://a, active: true, healthy: true)');
    });
  });

  group('RelayListEvent.fromEvent', () {
    test('extracts relay urls from the r tags of a kind 10002 event', () {
      final parsed = RelayListEvent.fromEvent(relayListEvent());

      expect(parsed, isNotNull);
      expect(parsed!.relays, ['wss://relay.one', 'wss://relay.two']);
      expect(parsed.authorPubkey, _authorPubkey);
      expect(parsed.publishedAt, _publishedAt);
    });

    test('returns null for a non-10002 event', () {
      expect(RelayListEvent.fromEvent(relayListEvent(kind: 1)), isNull);
    });

    test('ignores tags that are not r tags or lack a value', () {
      final parsed = RelayListEvent.fromEvent(relayListEvent(tags: const [
        ['p', 'somepubkey'],
        ['r'],
        ['r', ''],
        ['r', 'wss://kept'],
      ]));

      expect(parsed!.relays, ['wss://kept']);
    });

    test('yields an empty relay list when there are no tags', () {
      final parsed = RelayListEvent.fromEvent(relayListEvent(tags: const []));

      expect(parsed!.relays, isEmpty);
      expect(parsed.validRelays, isEmpty);
    });
  });

  group('RelayListEvent.validRelays', () {
    test('keeps only websocket urls', () {
      final event = relayList([
        'wss://secure.relay',
        'ws://plain.relay',
        'https://not-a-relay',
        'relay.example',
      ]);

      expect(event.validRelays, ['wss://secure.relay', 'ws://plain.relay']);
    });

    test('strips a single trailing slash', () {
      expect(relayList(['wss://relay.example/']).validRelays,
          ['wss://relay.example']);
    });

    test('strips repeated trailing slashes', () {
      expect(relayList(['wss://relay.example///']).validRelays,
          ['wss://relay.example']);
    });

    test('leaves urls without a trailing slash untouched', () {
      expect(relayList(['wss://relay.example']).validRelays,
          ['wss://relay.example']);
    });
  });

  group('RelayListEvent equality', () {
    test('is order-insensitive over the relay set', () {
      final a = relayList(['wss://one', 'wss://two']);
      final b = relayList(['wss://two', 'wss://one']);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('differs when the author or the relay set differs', () {
      final base = relayList(['wss://one']);

      expect(base, isNot(relayList(['wss://one'], author: 'other-author')));
      expect(base, isNot(relayList(['wss://one', 'wss://two'])));
      expect(base, isNot(equals('not a relay list event')));
      expect(base, equals(base));
    });

    test('renders relays, timestamp and author', () {
      final event = relayList(['wss://one']);

      expect(event.toString(), contains('wss://one'));
      expect(event.toString(), contains('author'));
    });
  });
}
