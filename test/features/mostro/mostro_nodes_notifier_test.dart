import 'dart:convert';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/data/models/enums/storage_keys.dart';
import 'package:mostro_mobile/features/mostro/mostro_node.dart';
import 'package:mostro_mobile/features/mostro/mostro_nodes_notifier.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_notifier.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';

import '../../mocks.dart';
import '../../mocks.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  provideDummy<Settings>(Settings(
    relays: [],
    fullPrivacyMode: false,
    mostroPublicKey: '',
  ));
  provideDummy<SettingsNotifier>(MockSettingsNotifier());
  provideDummy<NostrService>(MockNostrService());

  group('MostroNodesNotifier', () {
    late MockSharedPreferencesAsync mockPrefs;
    late MockRef mockRef;
    late MockSettingsNotifier mockSettingsNotifier;
    final trustedPubkey = Config.trustedMostroNodes.first['pubkey']!;

    Settings makeSettings({String? mostroPublicKey}) {
      return Settings(
        relays: [],
        fullPrivacyMode: false,
        mostroPublicKey: mostroPublicKey ?? trustedPubkey,
      );
    }

    setUp(() {
      mockPrefs = MockSharedPreferencesAsync();
      mockRef = MockRef();
      mockSettingsNotifier = MockSettingsNotifier();

      when(mockPrefs.getString(any)).thenAnswer((_) async => null);
      when(mockPrefs.setString(any, any)).thenAnswer((_) async {});

      mockSettingsNotifier.state = makeSettings();
      when(mockRef.read(settingsProvider)).thenReturn(mockSettingsNotifier.state);
      when(mockRef.read(settingsProvider.notifier))
          .thenReturn(mockSettingsNotifier);
    });

    MostroNodesNotifier createNotifier() {
      return MostroNodesNotifier(mockPrefs, mockRef);
    }

    test('init loads trusted nodes from Config', () async {
      final notifier = createNotifier();
      await notifier.init();

      expect(notifier.trustedNodes.length, Config.trustedMostroNodes.length);
      expect(notifier.trustedNodes.first.pubkey, trustedPubkey);
      expect(notifier.trustedNodes.first.isTrusted, true);
      expect(notifier.trustedNodes.first.name, 'Mostro P2P');
    });

    test('init loads custom nodes from SharedPreferences', () async {
      final customNodes = [
        MostroNode(
          pubkey: 'custom_pubkey_12345678901234567890',
          name: 'My Custom Node',
          addedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        ).toJson(),
      ];
      when(mockPrefs.getString(
        SharedPreferencesKeys.mostroCustomNodes.value,
      )).thenAnswer((_) async => jsonEncode(customNodes));

      final notifier = createNotifier();
      await notifier.init();

      expect(notifier.customNodes.length, 1);
      expect(notifier.customNodes.first.pubkey,
          'custom_pubkey_12345678901234567890');
      expect(notifier.customNodes.first.name, 'My Custom Node');
      expect(notifier.customNodes.first.isTrusted, false);
    });

    test('init merges trusted and custom nodes', () async {
      final customNodes = [
        MostroNode(
          pubkey: 'custom_pubkey_12345678901234567890',
          addedAt: DateTime.now(),
        ).toJson(),
      ];
      when(mockPrefs.getString(
        SharedPreferencesKeys.mostroCustomNodes.value,
      )).thenAnswer((_) async => jsonEncode(customNodes));

      final notifier = createNotifier();
      await notifier.init();

      expect(
        notifier.state.length,
        Config.trustedMostroNodes.length + 1,
      );
    });

    test('init auto-imports unrecognized mostroPublicKey as custom node',
        () async {
      final unknownPubkey =
          'aabbccdd11223344aabbccdd11223344aabbccdd11223344aabbccdd11223344';
      mockSettingsNotifier.state = makeSettings(
        mostroPublicKey: unknownPubkey,
      );
      when(mockRef.read(settingsProvider))
          .thenReturn(mockSettingsNotifier.state);

      final notifier = createNotifier();
      await notifier.init();

      final customNodes = notifier.customNodes;
      expect(customNodes.length, 1);
      expect(customNodes.first.pubkey, unknownPubkey);
      expect(customNodes.first.isTrusted, false);
      expect(customNodes.first.addedAt, isNotNull);

      // Verify it was persisted
      verify(mockPrefs.setString(
        SharedPreferencesKeys.mostroCustomNodes.value,
        any,
      )).called(1);
    });

    test('init does not auto-import invalid/malformed pubkey', () async {
      mockSettingsNotifier.state = makeSettings(
        mostroPublicKey: 'not-a-valid-hex-pubkey',
      );
      when(mockRef.read(settingsProvider))
          .thenReturn(mockSettingsNotifier.state);

      final notifier = createNotifier();
      await notifier.init();

      expect(notifier.customNodes, isEmpty);
    });

    test('init does not auto-import when pubkey matches trusted node',
        () async {
      final notifier = createNotifier();
      await notifier.init();

      expect(notifier.customNodes, isEmpty);
    });

    test('init does not auto-import when pubkey is empty', () async {
      mockSettingsNotifier.state = makeSettings(mostroPublicKey: '');
      when(mockRef.read(settingsProvider))
          .thenReturn(mockSettingsNotifier.state);

      final notifier = createNotifier();
      await notifier.init();

      expect(notifier.customNodes, isEmpty);
    });

    test('selectedNode returns matching node', () async {
      final notifier = createNotifier();
      await notifier.init();

      expect(notifier.selectedNode, isNotNull);
      expect(notifier.selectedNode!.pubkey, trustedPubkey);
    });

    test('selectedNode returns null for unmatched pubkey', () async {
      mockSettingsNotifier.state =
          makeSettings(mostroPublicKey: 'nonexistent_key_123456');
      when(mockRef.read(settingsProvider))
          .thenReturn(mockSettingsNotifier.state);

      final notifier = createNotifier();
      // Set state directly without init to avoid auto-import
      notifier.state = [
        MostroNode(pubkey: trustedPubkey, isTrusted: true),
      ];

      expect(notifier.selectedNode, isNull);
    });

    test('addCustomNode succeeds for new pubkey', () async {
      final notifier = createNotifier();
      await notifier.init();

      final result = await notifier.addCustomNode(
        'aa11bb22cc33dd44aa11bb22cc33dd44aa11bb22cc33dd44aa11bb22cc33dd44',
        name: 'New Node',
      );

      expect(result, true);
      expect(notifier.customNodes.length, 1);
      expect(
        notifier.customNodes.first.pubkey,
        'aa11bb22cc33dd44aa11bb22cc33dd44aa11bb22cc33dd44aa11bb22cc33dd44',
      );
      expect(notifier.customNodes.first.name, 'New Node');
    });

    test('addCustomNode rejects invalid pubkey format', () async {
      final notifier = createNotifier();
      await notifier.init();

      final result = await notifier.addCustomNode(
        'not-a-valid-hex-pubkey',
        name: 'Invalid Node',
      );

      expect(result, false);
      expect(
        notifier.customNodes,
        isEmpty,
      );
    });

    test('addCustomNode rejects duplicate pubkey', () async {
      final notifier = createNotifier();
      await notifier.init();

      // Try to add with same pubkey as trusted node
      final result = await notifier.addCustomNode(trustedPubkey);

      expect(result, false);
    });

    test('addCustomNode persists to SharedPreferences', () async {
      final notifier = createNotifier();
      await notifier.init();

      await notifier.addCustomNode(
        'bb22cc33dd44ee55bb22cc33dd44ee55bb22cc33dd44ee55bb22cc33dd44ee55',
        name: 'Saved Node',
      );

      verify(mockPrefs.setString(
        SharedPreferencesKeys.mostroCustomNodes.value,
        any,
      )).called(1);
    });

    test('removeCustomNode succeeds for non-active custom node', () async {
      final notifier = createNotifier();
      await notifier.init();

      await notifier.addCustomNode(
        'cc33dd44ee55ff66cc33dd44ee55ff66cc33dd44ee55ff66cc33dd44ee55ff66',
        name: 'Removable',
      );
      // Reset the verification count
      clearInteractions(mockPrefs);
      when(mockPrefs.setString(any, any)).thenAnswer((_) async {});

      final result = await notifier.removeCustomNode(
        'cc33dd44ee55ff66cc33dd44ee55ff66cc33dd44ee55ff66cc33dd44ee55ff66',
      );

      expect(result, true);
      expect(notifier.customNodes, isEmpty);
    });

    test('removeCustomNode fails for trusted node', () async {
      final notifier = createNotifier();
      await notifier.init();

      final result = await notifier.removeCustomNode(trustedPubkey);

      expect(result, false);
    });

    test('removeCustomNode fails for currently active node', () async {
      final customPubkey =
          '1122334455667788112233445566778811223344556677881122334455667788';
      mockSettingsNotifier.state = makeSettings(
        mostroPublicKey: customPubkey,
      );
      when(mockRef.read(settingsProvider))
          .thenReturn(mockSettingsNotifier.state);

      final notifier = createNotifier();
      await notifier.init();

      // The auto-import adds it as custom, and it's active
      final result = await notifier.removeCustomNode(customPubkey);

      expect(result, false);
    });

    test('updateCustomNodeName updates name for custom node', () async {
      final notifier = createNotifier();
      await notifier.init();
      await notifier.addCustomNode(
        'dd44ee55ff660011dd44ee55ff660011dd44ee55ff660011dd44ee55ff660011',
        name: 'Old Name',
      );

      await notifier.updateCustomNodeName(
        'dd44ee55ff660011dd44ee55ff660011dd44ee55ff660011dd44ee55ff660011',
        'New Name',
      );

      final node = notifier.customNodes.firstWhere(
        (n) => n.pubkey == 'dd44ee55ff660011dd44ee55ff660011dd44ee55ff660011dd44ee55ff660011',
      );
      expect(node.name, 'New Name');
    });

    test('updateCustomNodeName does not update trusted nodes', () async {
      final notifier = createNotifier();
      await notifier.init();

      await notifier.updateCustomNodeName(trustedPubkey, 'Hacked Name');

      final trusted = notifier.trustedNodes.first;
      expect(trusted.name, 'Mostro P2P');
    });

    test('updateNodeMetadata updates metadata for any node', () async {
      final notifier = createNotifier();
      await notifier.init();

      notifier.updateNodeMetadata(
        trustedPubkey,
        name: 'Updated Name',
        picture: 'https://example.com/pic.png',
        website: 'https://example.com',
        about: 'A description',
      );

      final node = notifier.state.firstWhere((n) => n.pubkey == trustedPubkey);
      expect(node.name, 'Updated Name');
      expect(node.picture, 'https://example.com/pic.png');
      expect(node.website, 'https://example.com');
      expect(node.about, 'A description');
    });

    test('isTrustedNode returns correct values', () async {
      final notifier = createNotifier();
      await notifier.init();
      await notifier.addCustomNode(
        'ee55ff66001122ee55ff66001122ee55ff66001122ee55ff66001122ee55ff66',
      );

      expect(notifier.isTrustedNode(trustedPubkey), true);
      expect(
        notifier.isTrustedNode('ee55ff66001122ee55ff66001122ee55ff66001122ee55ff66001122ee55ff66'),
        false,
      );
      expect(notifier.isTrustedNode('nonexistent_key_1234567890'), false);
    });

    test('init handles corrupt SharedPreferences gracefully', () async {
      when(mockPrefs.getString(
        SharedPreferencesKeys.mostroCustomNodes.value,
      )).thenAnswer((_) async => 'not valid json');

      final notifier = createNotifier();
      await notifier.init();

      // Should still have trusted nodes, no custom
      expect(notifier.trustedNodes.length, Config.trustedMostroNodes.length);
      expect(notifier.customNodes, isEmpty);
    });

    test('selectNode updates settings for known node', () async {
      final notifier = createNotifier();
      await notifier.init();

      // selectNode delegates to settingsNotifier.updateMostroInstance
      // which updates state.mostroPublicKey
      await notifier.selectNode(trustedPubkey);

      expect(mockSettingsNotifier.state.mostroPublicKey, trustedPubkey);
    });

    test('selectNode does nothing for unknown pubkey', () async {
      final notifier = createNotifier();
      await notifier.init();

      final pubkeyBefore = mockSettingsNotifier.state.mostroPublicKey;
      await notifier.selectNode('nonexistent_pubkey_1234567890');

      // State unchanged since the node wasn't found
      expect(mockSettingsNotifier.state.mostroPublicKey, pubkeyBefore);
    });

    group('metadata fetching', () {
      late MockNostrService mockNostrService;
      // Real keypair so events are properly signed and pass isVerified()
      final testKeyPair = NostrKeyPairs.generate();

      NostrEvent makeKind0Event(
        Map<String, dynamic> metadata, {
        DateTime? createdAt,
      }) {
        return NostrEvent.fromPartialData(
          kind: 0,
          content: jsonEncode(metadata),
          keyPairs: testKeyPair,
          createdAt: createdAt ?? DateTime(2025),
        );
      }

      setUp(() {
        mockNostrService = MockNostrService();
        when(mockRef.read(nostrServiceProvider))
            .thenReturn(mockNostrService);
      });

      /// Helper to add a node with testKeyPair's pubkey to the notifier
      Future<MostroNodesNotifier> createNotifierWithTestNode() async {
        final notifier = createNotifier();
        await notifier.init();
        // Add a node matching the test keypair's pubkey
        notifier.updateNodeMetadata(testKeyPair.public, name: 'Test Node');
        // Ensure the node exists in state
        if (!notifier.state.any((n) => n.pubkey == testKeyPair.public)) {
          notifier.state = [
            ...notifier.state,
            MostroNode(pubkey: testKeyPair.public, name: 'Test Node'),
          ];
        }
        return notifier;
      }

      test('fetchAllNodeMetadata fetches and applies kind 0 events', () async {
        final notifier = await createNotifierWithTestNode();

        when(mockNostrService.fetchEvents(any, specificRelays: anyNamed('specificRelays')))
            .thenAnswer((_) async => [
                  makeKind0Event({
                    'name': 'Mostro Official',
                    'picture': 'https://example.com/pic.png',
                    'website': 'https://mostro.network',
                    'about': 'P2P trading node',
                  }),
                ]);

        await notifier.fetchAllNodeMetadata();

        final node =
            notifier.state.firstWhere((n) => n.pubkey == testKeyPair.public);
        expect(node.name, 'Mostro Official');
        expect(node.picture, 'https://example.com/pic.png');
        expect(node.website, 'https://mostro.network');
        expect(node.about, 'P2P trading node');
      });

      test('fetchAllNodeMetadata deduplicates by pubkey keeping latest',
          () async {
        final notifier = await createNotifierWithTestNode();

        when(mockNostrService.fetchEvents(any, specificRelays: anyNamed('specificRelays')))
            .thenAnswer((_) async => [
                  makeKind0Event(
                    {'name': 'Old Name'},
                    createdAt: DateTime(2024),
                  ),
                  makeKind0Event(
                    {'name': 'New Name'},
                    createdAt: DateTime(2025),
                  ),
                ]);

        await notifier.fetchAllNodeMetadata();

        final node =
            notifier.state.firstWhere((n) => n.pubkey == testKeyPair.public);
        expect(node.name, 'New Name');
      });

      test('fetchAllNodeMetadata rejects non-https picture and website URLs',
          () async {
        final notifier = await createNotifierWithTestNode();

        when(mockNostrService.fetchEvents(any, specificRelays: anyNamed('specificRelays')))
            .thenAnswer((_) async => [
                  makeKind0Event({
                    'name': 'Valid Name',
                    'picture': 'javascript:alert(1)',
                    'website': 'http://phishing.com',
                  }),
                ]);

        await notifier.fetchAllNodeMetadata();

        final node =
            notifier.state.firstWhere((n) => n.pubkey == testKeyPair.public);
        expect(node.name, 'Valid Name');
        expect(node.picture, isNull);
        expect(node.website, isNull);
      });

      test('fetchAllNodeMetadata accepts valid https URLs', () async {
        final notifier = await createNotifierWithTestNode();

        when(mockNostrService.fetchEvents(any, specificRelays: anyNamed('specificRelays')))
            .thenAnswer((_) async => [
                  makeKind0Event({
                    'picture': 'https://example.com/avatar.png',
                    'website': 'https://mostro.network',
                  }),
                ]);

        await notifier.fetchAllNodeMetadata();

        final node =
            notifier.state.firstWhere((n) => n.pubkey == testKeyPair.public);
        expect(node.picture, 'https://example.com/avatar.png');
        expect(node.website, 'https://mostro.network');
      });

      test('fetchAllNodeMetadata handles empty event list gracefully',
          () async {
        final notifier = createNotifier();
        await notifier.init();
        final stateBefore = notifier.state.toList();

        when(mockNostrService.fetchEvents(any, specificRelays: anyNamed('specificRelays')))
            .thenAnswer((_) async => []);

        await notifier.fetchAllNodeMetadata();

        expect(notifier.state.length, stateBefore.length);
      });

      test('fetchAllNodeMetadata handles malformed JSON content', () async {
        final notifier = await createNotifierWithTestNode();

        when(mockNostrService.fetchEvents(any, specificRelays: anyNamed('specificRelays')))
            .thenAnswer((_) async => [
                  NostrEvent.fromPartialData(
                    kind: 0,
                    content: 'not valid json{{{',
                    keyPairs: testKeyPair,
                    createdAt: DateTime(2025),
                  ),
                ]);

        // Should not throw
        await notifier.fetchAllNodeMetadata();

        // Name should remain unchanged
        final node =
            notifier.state.firstWhere((n) => n.pubkey == testKeyPair.public);
        expect(node.name, 'Test Node');
      });

      test('fetchAllNodeMetadata handles network error gracefully', () async {
        final notifier = createNotifier();
        await notifier.init();
        final stateBefore = notifier.state.toList();

        when(mockNostrService.fetchEvents(any, specificRelays: anyNamed('specificRelays')))
            .thenThrow(Exception('Network error'));

        // Should not throw
        await notifier.fetchAllNodeMetadata();

        expect(notifier.state.length, stateBefore.length);
      });

      test('fetchAllNodeMetadata applies unverified events with warning', () async {
        final notifier = createNotifier();
        await notifier.init();

        when(mockNostrService.fetchEvents(any, specificRelays: anyNamed('specificRelays')))
            .thenAnswer((_) async => [
                  NostrEvent(
                    id: 'a' * 64,
                    kind: 0,
                    content: jsonEncode({'name': 'Unverified Name'}),
                    sig: 'b' * 128,
                    pubkey: trustedPubkey,
                    createdAt: DateTime(2025),
                    tags: const [],
                  ),
                ]);

        await notifier.fetchAllNodeMetadata();

        // Metadata is applied even if signature verification fails,
        // since events are fetched by author filter
        final node =
            notifier.state.firstWhere((n) => n.pubkey == trustedPubkey);
        expect(node.name, 'Unverified Name');
      });

      test('fetchNodeMetadata deduplicates keeping latest when relays return multiple events',
          () async {
        final notifier = await createNotifierWithTestNode();

        when(mockNostrService.fetchEvents(any, specificRelays: anyNamed('specificRelays')))
            .thenAnswer((_) async => [
                  makeKind0Event(
                    {'name': 'Old Name'},
                    createdAt: DateTime(2024),
                  ),
                  makeKind0Event(
                    {'name': 'Latest Name'},
                    createdAt: DateTime(2025),
                  ),
                  makeKind0Event(
                    {'name': 'Middle Name'},
                    createdAt: DateTime(2024, 6),
                  ),
                ]);

        await notifier.fetchNodeMetadata(testKeyPair.public);

        final node =
            notifier.state.firstWhere((n) => n.pubkey == testKeyPair.public);
        expect(node.name, 'Latest Name');
      });

      test('fetchNodeMetadata fetches single node', () async {
        final notifier = await createNotifierWithTestNode();

        when(mockNostrService.fetchEvents(any, specificRelays: anyNamed('specificRelays')))
            .thenAnswer((_) async => [
                  makeKind0Event({
                    'name': 'Single Fetch Name',
                    'about': 'Single fetch about',
                  }),
                ]);

        await notifier.fetchNodeMetadata(testKeyPair.public);

        final node =
            notifier.state.firstWhere((n) => n.pubkey == testKeyPair.public);
        expect(node.name, 'Single Fetch Name');
        expect(node.about, 'Single fetch about');
      });

      test('_applyMetadataFromEvent skips non-map JSON', () async {
        final notifier = await createNotifierWithTestNode();

        when(mockNostrService.fetchEvents(any, specificRelays: anyNamed('specificRelays')))
            .thenAnswer((_) async => [
                  NostrEvent.fromPartialData(
                    kind: 0,
                    content: '"just a string"',
                    keyPairs: testKeyPair,
                    createdAt: DateTime(2025),
                  ),
                ]);

        // Should not throw
        await notifier.fetchAllNodeMetadata();

        // Name should remain unchanged
        final node =
            notifier.state.firstWhere((n) => n.pubkey == testKeyPair.public);
        expect(node.name, 'Test Node');
      });
    });
  });
}
