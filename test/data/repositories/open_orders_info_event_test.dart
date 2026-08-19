import 'dart:async';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/data/repositories/open_orders_repository.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

import '../../mocks.mocks.dart';

/// Builds a kind-38385 info event of the shape mostrod publishes: empty
/// content, everything carried in tags.
NostrEvent _signedInfoEvent(
  NostrKeyPairs keyPair, {
  String protocolVersion = '2',
  DateTime? createdAt,
}) {
  return NostrEvent.fromPartialData(
    kind: 38385,
    content: '',
    keyPairs: keyPair,
    createdAt: createdAt,
    tags: [
      ['d', 'info'],
      ['y', 'mostro'],
      ['z', 'info'],
      ['protocol_version', protocolVersion],
    ],
  );
}

/// Re-tags [source] while keeping its original id/sig/pubkey — what a relay
/// can do for free, and what `NostrEvent.isVerified()` fails to catch.
NostrEvent _reTagged(NostrEvent source, List<List<String>> tags) {
  return NostrEvent(
    id: source.id,
    sig: source.sig,
    pubkey: source.pubkey,
    kind: source.kind,
    content: source.content,
    createdAt: source.createdAt,
    tags: tags,
  );
}

void main() {
  late MockNostrService mockNostrService;
  late StreamController<NostrEvent> eventController;
  late NostrKeyPairs nodeKeys;
  late Settings settings;

  setUp(() {
    nodeKeys = NostrUtils.generateKeyPair();
    mockNostrService = MockNostrService();
    eventController = StreamController<NostrEvent>.broadcast();

    settings = Settings(
      relays: const ['wss://relay.example'],
      fullPrivacyMode: false,
      mostroPublicKey: nodeKeys.public,
    );

    when(mockNostrService.isInitialized).thenReturn(true);
    when(mockNostrService.subscribeToEvents(any))
        .thenAnswer((_) => eventController.stream);
  });

  tearDown(() async {
    await eventController.close();
  });

  OpenOrdersRepository buildRepository() =>
      OpenOrdersRepository(mockNostrService, settings);

  group('OpenOrdersRepository info event (kind 38385) verification', () {
    test('accepts a genuinely signed info event from the configured node',
        () async {
      final repository = buildRepository();
      final event = _signedInfoEvent(nodeKeys);

      eventController.add(event);
      await pumpEventQueue();

      expect(repository.mostroInstance, isNotNull);
      expect(repository.mostroInstance!.id, event.id);
    });

    test('emits the accepted info event on mostroInstanceStream', () async {
      final repository = buildRepository();
      final emitted = repository.mostroInstanceStream.first;

      eventController.add(_signedInfoEvent(nodeKeys));

      expect((await emitted).kind, 38385);
    });

    test('rejects an info event whose signature does not verify', () async {
      final repository = buildRepository();
      final genuine = _signedInfoEvent(nodeKeys);

      final forged = NostrEvent(
        id: genuine.id,
        sig: 'f' * 128,
        pubkey: nodeKeys.public,
        kind: genuine.kind,
        content: genuine.content,
        createdAt: genuine.createdAt,
        tags: genuine.tags,
      );

      eventController.add(forged);
      await pumpEventQueue();

      expect(repository.mostroInstance, isNull);
    });

    // The downgrade primitive this guard exists for: flip protocol_version
    // 2 -> 1 on a genuine event, keeping the node's real pubkey and a real
    // signature triple. Accepting this pins the client to the v1 gift-wrap
    // transport, whose intake authenticates nothing.
    test('rejects a protocol_version downgrade re-tagged onto a real signature',
        () async {
      final repository = buildRepository();
      final genuine = _signedInfoEvent(nodeKeys, protocolVersion: '2');

      final downgraded = _reTagged(genuine, [
        ['d', 'info'],
        ['y', 'mostro'],
        ['z', 'info'],
        ['protocol_version', '1'],
      ]);

      // The weak check the codebase reaches for elsewhere would allow this.
      expect(downgraded.isVerified(), isTrue);

      eventController.add(downgraded);
      await pumpEventQueue();

      expect(repository.mostroInstance, isNull);
    });

    test('rejects an info event authored by a different key', () async {
      final repository = buildRepository();
      final impostor = NostrUtils.generateKeyPair();

      eventController.add(_signedInfoEvent(impostor, protocolVersion: '1'));
      await pumpEventQueue();

      expect(repository.mostroInstance, isNull);
    });

    test('a rejected event does not evict an already accepted one', () async {
      final repository = buildRepository();
      final genuine = _signedInfoEvent(nodeKeys);

      eventController.add(genuine);
      await pumpEventQueue();
      expect(repository.mostroInstance, isNotNull);

      eventController.add(_reTagged(genuine, [
        ['d', 'info'],
        ['y', 'mostro'],
        ['z', 'info'],
        ['protocol_version', '1'],
      ]));
      await pumpEventQueue();

      expect(repository.mostroInstance!.id, genuine.id);
      expect(
        repository.mostroInstance!.tags,
        contains(equals(['protocol_version', '2'])),
      );
    });
  });

  group('OpenOrdersRepository info event freshness', () {
    // Signature validity says the node authored the event, not that it is
    // current. A relay that holds on to a superseded info event can replay it
    // to roll the node's advertised config back — the downgrade path that
    // survives signature verification.
    test('ignores a signed but superseded info event', () async {
      final repository = buildRepository();
      final now = DateTime.now();

      final current = _signedInfoEvent(
        nodeKeys,
        protocolVersion: '2',
        createdAt: now,
      );
      final superseded = _signedInfoEvent(
        nodeKeys,
        protocolVersion: '1',
        createdAt: now.subtract(const Duration(days: 30)),
      );

      eventController.add(current);
      await pumpEventQueue();
      eventController.add(superseded);
      await pumpEventQueue();

      // Both are genuinely signed; only recency separates them.
      expect(NostrUtils.isValidEventSignature(superseded), isTrue);
      expect(repository.mostroInstance!.id, current.id);
    });

    test('applies a newer info event', () async {
      final repository = buildRepository();
      final now = DateTime.now();

      final older = _signedInfoEvent(
        nodeKeys,
        createdAt: now.subtract(const Duration(hours: 1)),
      );
      final newer = _signedInfoEvent(nodeKeys, createdAt: now);

      eventController.add(older);
      await pumpEventQueue();
      eventController.add(newer);
      await pumpEventQueue();

      expect(repository.mostroInstance!.id, newer.id);
    });

    test('ignores a re-delivery of the already accepted event', () async {
      final repository = buildRepository();
      final event = _signedInfoEvent(nodeKeys, createdAt: DateTime.now());

      final emissions = <NostrEvent>[];
      final sub = repository.mostroInstanceStream.listen(emissions.add);

      // The same event arriving from several relays must not re-emit.
      eventController.add(event);
      await pumpEventQueue();
      eventController.add(event);
      await pumpEventQueue();

      expect(emissions, hasLength(1));
      await sub.cancel();
    });

    test('accepts the newly selected node info after an instance switch',
        () async {
      final repository = buildRepository();
      final now = DateTime.now();

      eventController.add(_signedInfoEvent(nodeKeys, createdAt: now));
      await pumpEventQueue();

      // The next node's info event is older in wall-clock terms; the switch
      // must not let the previous node's timestamp shut it out.
      final nextNodeKeys = NostrUtils.generateKeyPair();
      repository.updateSettings(
        settings.copyWith(mostroPublicKey: nextNodeKeys.public),
      );

      final nextInfo = _signedInfoEvent(
        nextNodeKeys,
        createdAt: now.subtract(const Duration(days: 7)),
      );
      eventController.add(nextInfo);
      await pumpEventQueue();

      expect(repository.mostroInstance!.id, nextInfo.id);
    });
  });
}
