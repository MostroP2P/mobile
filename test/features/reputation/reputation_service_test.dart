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
import 'package:mostro_mobile/features/reputation/reputation_attestation.dart';
import 'package:mostro_mobile/features/reputation/reputation_service.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_notifier.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../mocks.mocks.dart';

final Map<String, dynamic> vectors = jsonDecode(
  File('test/fixtures/reputation_v1.json').readAsStringSync(),
) as Map<String, dynamic>;

const node = 'b7c43ced472a22aa19e981a70699ae000c4f5c7422639429b6c5e9287119beed';

class _Settings extends SettingsNotifier {
  _Settings({bool fullPrivacy = false}) : super(MockSharedPreferencesAsync()) {
    state = Settings(
      relays: const [],
      fullPrivacyMode: fullPrivacy,
      mostroPublicKey: node,
    );
  }
}

/// A node that answers every request with [reply] and records what it got.
class _FakeNode implements ReputationTransport {
  Map<String, dynamic> reply;
  final List<MostroMessage> received = [];
  final List<NostrKeyPairs> identities = [];

  _FakeNode(this.reply);

  @override
  Future<Map<String, dynamic>> request(
    MostroMessage message, {
    required String node,
    required NostrKeyPairs tradeKey,
    required NostrKeyPairs identity,
  }) async {
    received.add(message);
    identities.add(identity);
    return reply;
  }
}

Map<String, dynamic> _reply(String action, Map<String, dynamic>? payload) => {
      'version': 2,
      'request_id': 1,
      'action': action,
      'payload': payload,
    };

NostrEvent _info(List<List<String>> tags) => NostrEvent(
      id: 'info',
      kind: 38385,
      content: '',
      sig: '',
      pubkey: node,
      createdAt: DateTime.now(),
      tags: [
        ['d', node],
        ...tags,
      ],
    );

void main() {
  final secrets = vectors['secret_keys'] as Map<String, dynamic>;
  final identity = NostrKeyPairs(private: secrets['identity'] as String);
  final issuer = NostrKeyPairs(private: secrets['issuer-a'] as String).public;
  final valid = vectors['attestation']['valid'] as Map<String, dynamic>;
  final validJson = valid['json'] as String;
  final now = vectors['context']['now'] as int;

  late MockOpenOrdersRepository orders;
  late MockKeyManager keys;

  ProviderContainer container(
    _FakeNode transport, {
    List<List<String>> infoTags = const [],
    bool fullPrivacy = false,
  }) {
    when(orders.awaitMostroInstance(timeout: anyNamed('timeout')))
        .thenAnswer((_) async => _info(infoTags));
    final c = ProviderContainer(overrides: [
      settingsProvider
          .overrideWith((ref) => _Settings(fullPrivacy: fullPrivacy)),
      orderRepositoryProvider.overrideWithValue(orders),
      keyManagerProvider.overrideWithValue(keys),
      sharedPreferencesProvider.overrideWithValue(SharedPreferencesAsync()),
      reputationServiceProvider.overrideWith(
        (ref) => ReputationService(ref, transport: transport, now: () => now),
      ),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<String?> pending() =>
      SharedPreferencesAsync().getString('pending_reputation_attestation');

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    orders = MockOpenOrdersRepository();
    keys = MockKeyManager();
    when(keys.masterKeyPair).thenReturn(identity);
    when(keys.getNextKeyIndex()).thenAnswer((_) async => 7);
    when(keys.deriveTradeKeyFromIndex(7)).thenAnswer((_) async =>
        NostrKeyPairs(private: secrets['other-identity'] as String));
  });

  group('export', () {
    test('asks the node for the identity, verifies the answer and keeps it',
        () async {
      final fake = _FakeNode(
          _reply('reputation-exported', {'reputation_attestation': validJson}));
      final c = container(fake, infoTags: [
        ['reputation_issuer', issuer]
      ]);
      final attestation =
          await c.read(reputationServiceProvider).exportReputation();

      expect(attestation.id, valid['id']);
      expect(attestation.ratingText, '4.87');
      final sent = fake.received.single;
      expect(sent.action, Action.exportReputation);
      expect((sent.payload as ReputationExportRequest).destination,
          identity.public);
      expect((sent.payload as ReputationExportRequest).rebind, isNull);
      expect(fake.identities.single.public, identity.public);
      expect(await pending(), validJson);
      expect((await c.read(reputationServiceProvider).pendingAttestation())!.id,
          valid['id']);
    });

    test('is never sent to a node that does not advertise it', () async {
      final fake = _FakeNode(
          _reply('reputation-exported', {'reputation_attestation': validJson}));
      final c = container(fake);
      await expectLater(
        c.read(reputationServiceProvider).exportReputation(),
        throwsA(isA<ReputationException>().having(
            (e) => e.reason, 'reason', ReputationService.nodeDoesNotExport)),
      );
      expect(fake.received, isEmpty);
    });

    test('is never sent in full privacy mode', () async {
      final fake = _FakeNode(
          _reply('reputation-exported', {'reputation_attestation': validJson}));
      final c = container(fake,
          infoTags: [
            ['reputation_issuer', issuer]
          ],
          fullPrivacy: true);
      await expectLater(
        c.read(reputationServiceProvider).exportReputation(),
        throwsA(isA<ReputationException>()
            .having((e) => e.reason, 'reason', 'reputation_identity_required')),
      );
      expect(fake.received, isEmpty);
    });

    test('surfaces the node refusal', () async {
      final fake = _FakeNode(
          _reply('cant-do', {'cant_do': 'not_eligible_for_reputation_export'}));
      final c = container(fake, infoTags: [
        ['reputation_issuer', issuer]
      ]);
      await expectLater(
        c.read(reputationServiceProvider).exportReputation(),
        throwsA(isA<ReputationException>().having((e) => e.reason, 'reason',
            CantDoReason.notEligibleForReputationExport.value)),
      );
      expect(await pending(), isNull);
    });

    test(
        'refuses an attestation signed by another key than the node advertises',
        () async {
      final fake = _FakeNode(
          _reply('reputation-exported', {'reputation_attestation': validJson}));
      final c = container(fake, infoTags: [
        ['reputation_issuer', identity.public]
      ]);
      await expectLater(
        c.read(reputationServiceProvider).exportReputation(),
        throwsA(isA<ReputationException>().having(
            (e) => e.reason, 'reason', 'invalid_reputation_attestation')),
      );
      expect(await pending(), isNull);
    });

    test('carries a rebind authorisation signed by the bound identity',
        () async {
      final fake = _FakeNode(
          _reply('reputation-exported', {'reputation_attestation': validJson}));
      final c = container(fake, infoTags: [
        ['reputation_issuer', issuer]
      ]);
      final service = c.read(reputationServiceProvider);
      final newIdentity =
          NostrKeyPairs(private: secrets['new-identity'] as String).public;
      final rebind =
          service.signRebind(issuer: issuer, newIdentity: newIdentity);
      final parsed = ReputationRebind.parse(rebind, now: now);
      expect(parsed.boundIdentity, identity.public);
      expect((parsed.issuer, parsed.newIdentity), (issuer, newIdentity));
    });

    test('sends the rebind authorisation with the export it authorises',
        () async {
      // Arrange: the identity the account was bound to authorised this one.
      final fake = _FakeNode(
          _reply('reputation-exported', {'reputation_attestation': validJson}));
      final c = container(fake, infoTags: [
        ['reputation_issuer', issuer]
      ]);
      final rebind = ReputationRebind.build(
        boundIdentity:
            NostrKeyPairs(private: secrets['new-identity'] as String),
        issuer: issuer,
        newIdentity: identity.public,
        createdAt: now,
      );

      // Act
      await c.read(reputationServiceProvider).exportReputation(rebind: rebind);

      // Assert
      final sent = fake.received.single.payload as ReputationExportRequest;
      expect((sent.destination, sent.rebind), (identity.public, rebind));
    });

    test('never sends a rebind for another identity or issuer', () async {
      // Arrange
      final fake = _FakeNode(
          _reply('reputation-exported', {'reputation_attestation': validJson}));
      final c = container(fake, infoTags: [
        ['reputation_issuer', issuer]
      ]);
      final bound = NostrKeyPairs(private: secrets['new-identity'] as String);
      final otherIdentity =
          NostrKeyPairs(private: secrets['other-identity'] as String).public;
      final otherIssuer =
          NostrKeyPairs(private: secrets['issuer-b'] as String).public;
      final refused = [
        // The node refuses a rebind whose p is not the request destination.
        ReputationRebind.build(
            boundIdentity: bound,
            issuer: issuer,
            newIdentity: otherIdentity,
            createdAt: now),
        ReputationRebind.build(
            boundIdentity: bound,
            issuer: otherIssuer,
            newIdentity: identity.public,
            createdAt: now),
        'not a rebind',
      ];

      for (final rebind in refused) {
        // Act / Assert
        await expectLater(
          c.read(reputationServiceProvider).exportReputation(rebind: rebind),
          throwsA(isA<ReputationException>()
              .having((e) => e.reason, 'reason', 'invalid_reputation_rebind')),
        );
      }
      expect(fake.received, isEmpty);
    });
  });

  group('import', () {
    test('sends the attestation unchanged and forgets it once imported',
        () async {
      SharedPreferencesAsync()
          .setString('pending_reputation_attestation', validJson);
      final fake = _FakeNode(_reply('reputation-imported', null));
      final c = container(fake, infoTags: [
        ['reputation_import_issuers', issuer]
      ]);
      await c.read(reputationServiceProvider).importReputation(validJson);

      final sent = fake.received.single;
      expect(sent.action, Action.importReputation);
      expect((sent.payload as ReputationAttestationPayload).attestation,
          validJson);
      expect(await pending(), isNull);
    });

    test('checks what it can before sending', () async {
      final fake = _FakeNode(_reply('reputation-imported', null));
      Future<void> refused(
              List<List<String>> tags, String json, String reason) =>
          expectLater(
            container(fake, infoTags: tags)
                .read(reputationServiceProvider)
                .importReputation(json),
            throwsA(isA<ReputationException>()
                .having((e) => e.reason, 'reason', reason)),
          );
      await refused(const [], validJson, ReputationService.nodeDoesNotImport);
      await refused([
        ['reputation_import_issuers', identity.public]
      ], validJson, 'untrusted_reputation_issuer');
      final forOther = jsonEncode((vectors['attestation']['invalid'] as List)
          .firstWhere((c) => c['name'] == 'identity_mismatch')['event']);
      await refused([
        ['reputation_import_issuers', issuer]
      ], forOther, 'reputation_identity_mismatch');
      await refused([
        ['reputation_import_issuers', issuer]
      ], '{}', 'invalid_reputation_attestation');
      expect(fake.received, isEmpty);
    });

    test('surfaces the node refusal', () async {
      final fake = _FakeNode(
          _reply('cant-do', {'cant_do': 'reputation_already_imported'}));
      final c = container(fake, infoTags: [
        ['reputation_import_issuers', issuer]
      ]);
      await expectLater(
        c.read(reputationServiceProvider).importReputation(validJson),
        throwsA(isA<ReputationException>()
            .having((e) => e.reason, 'reason', 'reputation_already_imported')),
      );
    });
  });
}
