import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/enums/cant_do_reason.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/features/reputation/reputation_service.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_notifier.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../mocks.mocks.dart';

/// Exercises [NostrReputationTransport] itself, below the service: the REQ it
/// opens, the order of subscription and publication, the kind 14 NIP-44 round
/// trip with a node that answers like mostrod, the timeout and the cleanup.
/// The relay is an in-memory stream, so the suite runs in `flutter test`
/// without a network; the round trip against a live mostrod is a manual step.
final Map<String, dynamic> vectors = jsonDecode(
  File('test/fixtures/reputation_v1.json').readAsStringSync(),
) as Map<String, dynamic>;

class _Settings extends SettingsNotifier {
  _Settings(String node) : super(MockSharedPreferencesAsync()) {
    state = Settings(
      relays: const [],
      fullPrivacyMode: false,
      mostroPublicKey: node,
    );
  }
}

/// An in-memory relay: records the REQ and the published events, and lets a
/// test push events to the open subscription.
class _Relay {
  final MockNostrService service = MockNostrService();
  final List<NostrRequest> requests = [];
  final List<NostrEvent> published = [];
  final List<bool> subscribedWhenPublished = [];
  StreamController<NostrEvent>? _subscription;
  bool cancelled = false;

  /// Called with each published event; the default never answers.
  Future<void> Function(NostrEvent event) onPublish = (_) async {};

  _Relay() {
    when(service.subscribeToEvents(any)).thenAnswer((invocation) {
      requests.add(invocation.positionalArguments.first as NostrRequest);
      _subscription = StreamController<NostrEvent>(
        onCancel: () => cancelled = true,
      );
      return _subscription!.stream;
    });
    when(service.publishEvent(any)).thenAnswer((invocation) async {
      final event = invocation.positionalArguments.first as NostrEvent;
      published.add(event);
      subscribedWhenPublished.add(_subscription?.hasListener ?? false);
      await onPublish(event);
    });
  }

  void deliver(NostrEvent event) => _subscription!.add(event);
}

void main() {
  final secrets = vectors['secret_keys'] as Map<String, dynamic>;
  final identity = NostrKeyPairs(private: secrets['identity'] as String);
  final tradeKey = NostrKeyPairs(private: secrets['other-identity'] as String);
  final issuer = NostrKeyPairs(private: secrets['issuer-a'] as String).public;
  final valid = vectors['attestation']['valid'] as Map<String, dynamic>;
  final validJson = valid['json'] as String;
  final now = vectors['context']['now'] as int;
  final node = NostrUtils.generateKeyPair();

  late _Relay relay;
  late MockOpenOrdersRepository orders;
  late MockKeyManager keys;

  List<List<String>> powTags = [];

  NostrEvent info() => NostrEvent(
        id: 'info',
        kind: 38385,
        content: '',
        sig: '',
        pubkey: node.public,
        createdAt: DateTime.now(),
        tags: [
          ['d', node.public],
          ['protocol_version', '2'],
          ['reputation_issuer', issuer],
          ...powTags,
        ],
      );

  ReputationService service({Duration timeout = const Duration(seconds: 5)}) {
    final c = ProviderContainer(overrides: [
      settingsProvider.overrideWith((ref) => _Settings(node.public)),
      orderRepositoryProvider.overrideWithValue(orders),
      keyManagerProvider.overrideWithValue(keys),
      nostrServiceProvider.overrideWithValue(relay.service),
      sharedPreferencesProvider.overrideWithValue(SharedPreferencesAsync()),
      reputationServiceProvider.overrideWith(
        (ref) => ReputationService(
          ref,
          transport: NostrReputationTransport(ref, timeout: timeout),
          now: () => now,
        ),
      ),
    ]);
    addTearDown(c.dispose);
    return c.read(reputationServiceProvider);
  }

  /// What the node reads from [request]: the decrypted message tuple.
  Future<List<dynamic>> openAsNode(NostrEvent request) async =>
      jsonDecode(await NostrUtils.decryptNIP44DirectEvent(
        request,
        node.private,
        expectedAuthor: tradeKey.public,
      )) as List<dynamic>;

  /// The node's reply to the trade key: a kind 14 it signs, as mostrod does.
  Future<NostrEvent> replyFrom(NostrKeyPairs author, MostroMessage message) =>
      message.wrapNip44(tradeKey: author, recipientPubKey: tradeKey.public);

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    powTags = [
      ['pow', '0'],
      ['pow_first_contact', '0'],
    ];
    relay = _Relay();
    orders = MockOpenOrdersRepository();
    keys = MockKeyManager();
    when(orders.awaitMostroInstance(timeout: anyNamed('timeout')))
        .thenAnswer((_) async => info());
    when(keys.masterKeyPair).thenReturn(identity);
    when(keys.getNextKeyIndex()).thenAnswer((_) async => 7);
    when(keys.deriveTradeKeyFromIndex(7)).thenAnswer((_) async => tradeKey);
  });

  test('subscribes on the trade key before publishing and reads the answer',
      () async {
    // Arrange: the node answers the export with the vector attestation.
    relay.onPublish = (request) async {
      final tuple = await openAsNode(request);
      final asked = MostroMessage.fromJson(tuple[0] as Map<String, dynamic>);
      expect(asked.action, Action.exportReputation);
      expect((asked.payload as ReputationExportRequest).destination,
          identity.public);
      expect((tuple[2] as List).first, identity.public,
          reason: 'the identity proof travels inside the ciphertext');
      relay.deliver(await replyFrom(
        node,
        MostroMessage(
          action: Action.reputationExported,
          requestId: asked.requestId,
          payload: ReputationAttestationPayload(validJson),
        ),
      ));
    };

    // Act
    final attestation = await service().exportReputation();

    // Assert
    expect(attestation.id, valid['id']);
    final filter = relay.requests.single.filters.single;
    expect(filter.kinds, [14]);
    expect(filter.authors, [node.public]);
    expect(filter.p, [tradeKey.public]);
    final request = relay.published.single;
    expect(request.kind, 14);
    expect(request.pubkey, tradeKey.public);
    expect(relay.subscribedWhenPublished.single, isTrue,
        reason: 'a reply published before the REQ opens would be missed');
    expect(relay.cancelled, isTrue);
  });

  test('ignores events on the subscription that the node did not author',
      () async {
    // Arrange: a stranger writes to the trade key before the node answers.
    final stranger = NostrUtils.generateKeyPair();
    relay.onPublish = (request) async {
      final asked = MostroMessage.fromJson(
          (await openAsNode(request))[0] as Map<String, dynamic>);
      relay.deliver(await replyFrom(
        stranger,
        MostroMessage(
          action: Action.cantDo,
          requestId: asked.requestId,
          payload: CantDo(cantDoReason: CantDoReason.notAllowedByStatus),
        ),
      ));
      relay.deliver(await replyFrom(
        node,
        MostroMessage(
          action: Action.reputationExported,
          requestId: asked.requestId,
          payload: ReputationAttestationPayload(validJson),
        ),
      ));
    };

    // Act
    final attestation = await service().exportReputation();

    // Assert
    expect(attestation.id, valid['id']);
  });

  test('gives up with no_response and closes the subscription', () async {
    // Arrange: the node never answers.
    final reputation = service(timeout: const Duration(milliseconds: 50));

    // Act / Assert
    await expectLater(
      reputation.exportReputation(),
      throwsA(isA<ReputationException>()
          .having((e) => e.reason, 'reason', ReputationService.noResponse)),
    );
    expect(relay.published, hasLength(1));
    expect(relay.cancelled, isTrue);
  });

  test('reports an answer it cannot read as invalid_payload', () async {
    // Arrange: the node signs a kind 14 the trade key cannot decrypt.
    relay.onPublish = (_) async {
      final unreadable = NostrEvent.fromPartialData(
        kind: 14,
        content: 'not a NIP-44 payload',
        keyPairs: node,
        tags: [
          ['p', tradeKey.public]
        ],
      );
      relay.deliver(unreadable);
    };

    // Act / Assert
    await expectLater(
      service().exportReputation(),
      throwsA(isA<ReputationException>()
          .having((e) => e.reason, 'reason', 'invalid_payload')),
    );
    expect(relay.cancelled, isTrue);
  });

  group('first-contact proof of work', () {
    int target(NostrEvent event) => int.parse(event.tags!
        .firstWhere((t) => t.first == 'nonce',
            orElse: () => ['nonce', '0', '0'])
        .last);

    int leadingZeroBits(String id) {
      var bits = 0;
      for (final digit in id.split('').map((c) => int.parse(c, radix: 16))) {
        if (digit != 0) {
          return bits + digit.toRadixString(2).padLeft(4, '0').indexOf('1');
        }
        bits += 4;
      }
      return bits;
    }

    test('mines a request at pow_first_contact, not pow', () async {
      // Arrange: the fresh trade key is unknown to the node, so the request
      // is a first contact; the node drops it silently below that toll.
      powTags = [
        ['pow', '2'],
        ['pow_first_contact', '6'],
      ];
      relay.onPublish = (request) async {
        final asked = MostroMessage.fromJson(
            (await openAsNode(request))[0] as Map<String, dynamic>);
        relay.deliver(await replyFrom(
          node,
          MostroMessage(
            action: Action.reputationExported,
            requestId: asked.requestId,
            payload: ReputationAttestationPayload(validJson),
          ),
        ));
      };

      // Act
      await service().exportReputation();

      // Assert
      final request = relay.published.single;
      expect(target(request), 6);
      expect(leadingZeroBits(request.id!), greaterThanOrEqualTo(6));
    });

    test('retries harder on silence when the node does not publish the toll',
        () async {
      // Arrange: an older v2 node may enforce a first-contact difficulty it
      // does not advertise, and answers an under-powered event with silence.
      powTags = [
        ['pow', '0'],
      ];
      final reputation = service(timeout: const Duration(milliseconds: 50));

      // Act / Assert
      await expectLater(
        reputation.exportReputation(),
        throwsA(isA<ReputationException>()
            .having((e) => e.reason, 'reason', ReputationService.noResponse)),
      );
      expect(relay.published.map(target), [0, 8, 16]);
      expect(relay.published.map((e) => e.id).toSet(), hasLength(3),
          reason: 'the node drops a re-sent identical event id');
      expect(relay.requests, hasLength(1));
      expect(relay.cancelled, isTrue);
    });

    test('guesses at most up to the cap', () {
      expect(NostrReputationTransport.difficulties(pow: 0), [0, 8, 16]);
      expect(NostrReputationTransport.difficulties(pow: 5), [5, 10, 16]);
      expect(NostrReputationTransport.difficulties(pow: 20), [20]);
      expect(
          NostrReputationTransport.difficulties(pow: 2, firstContact: 1), [2]);
      expect(NostrReputationTransport.difficulties(pow: 2, firstContact: 30),
          [NostrUtils.maxPowDifficulty]);
    });
  });
}
