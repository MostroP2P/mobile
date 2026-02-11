import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/data/models/enums/storage_keys.dart';
import 'package:mostro_mobile/features/mostro/mostro_nodes_notifier.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_notifier.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/services/nostr_service.dart';

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

  final trustedPubkey = Config.trustedMostroNodes.first['pubkey']!;

  // Valid 64-char hex pubkeys for testing
  const customPubkeyA =
      'aa11bb22cc33dd44aa11bb22cc33dd44aa11bb22cc33dd44aa11bb22cc33dd44';
  const customPubkeyB =
      'bb22cc33dd44ee55bb22cc33dd44ee55bb22cc33dd44ee55bb22cc33dd44ee55';

  group('Multi-Mostro Integration Tests', () {
    late MockSharedPreferencesAsync mockPrefs;
    late MockRef mockRef;
    late MockSettingsNotifier mockSettingsNotifier;

    // In-memory storage to enable persistence round-trips
    late Map<String, String> storage;

    Settings makeSettings({
      String? mostroPublicKey,
      List<String>? relays,
      List<String>? blacklistedRelays,
      List<Map<String, dynamic>>? userRelays,
    }) {
      return Settings(
        relays: relays ?? ['wss://default.example.com'],
        fullPrivacyMode: false,
        mostroPublicKey: mostroPublicKey ?? trustedPubkey,
        blacklistedRelays: blacklistedRelays ?? const [],
        userRelays: userRelays ?? const [],
      );
    }

    setUp(() {
      mockPrefs = MockSharedPreferencesAsync();
      mockRef = MockRef();
      mockSettingsNotifier = MockSettingsNotifier();
      storage = <String, String>{};

      // Wire in-memory storage for persistence round-trips
      when(mockPrefs.getString(any)).thenAnswer(
          (inv) async => storage[inv.positionalArguments[0] as String]);
      when(mockPrefs.setString(any, any)).thenAnswer((inv) async {
        storage[inv.positionalArguments[0] as String] =
            inv.positionalArguments[1] as String;
      });

      mockSettingsNotifier.state = makeSettings();
      // Return current state dynamically so changes from updateMostroInstance
      // are visible to subsequent reads (e.g. selectedNode, removeCustomNode)
      when(mockRef.read(settingsProvider))
          .thenAnswer((_) => mockSettingsNotifier.state);
      when(mockRef.read(settingsProvider.notifier))
          .thenReturn(mockSettingsNotifier);
    });

    MostroNodesNotifier createNotifier() {
      return MostroNodesNotifier(mockPrefs, mockRef);
    }

    group('Node switching flows', () {
      test('switch to custom node updates settings with relay reset', () async {
        final notifier = createNotifier();
        await notifier.init();

        // Pre-populate blacklist and userRelays
        mockSettingsNotifier.state = makeSettings(
          blacklistedRelays: ['wss://relay1.example.com'],
          userRelays: [
            {'url': 'wss://myrelay.example.com'}
          ],
        );

        // Add and select a custom node
        await notifier.addCustomNode(customPubkeyA, name: 'Custom A');
        await notifier.selectNode(customPubkeyA);

        // Verify settings updated: pubkey changed, relays reset
        expect(
          mockSettingsNotifier.state.mostroPublicKey,
          customPubkeyA,
        );
        expect(mockSettingsNotifier.state.blacklistedRelays, isEmpty);
        expect(mockSettingsNotifier.state.userRelays, isEmpty);
      });

      test('switch between trusted and custom nodes resets relays', () async {
        final notifier = createNotifier();
        await notifier.init();
        await notifier.addCustomNode(customPubkeyA, name: 'Custom A');

        // Switch to custom
        await notifier.selectNode(customPubkeyA);
        expect(
          mockSettingsNotifier.state.mostroPublicKey,
          customPubkeyA,
        );

        // Simulate user adding relays while on custom node
        mockSettingsNotifier.state = mockSettingsNotifier.state.copyWith(
          blacklistedRelays: ['wss://blocked.example.com'],
          userRelays: [
            {'url': 'wss://custom-user.example.com'}
          ],
        );

        // Switch back to trusted
        await notifier.selectNode(trustedPubkey);
        expect(
          mockSettingsNotifier.state.mostroPublicKey,
          trustedPubkey,
        );
        expect(mockSettingsNotifier.state.blacklistedRelays, isEmpty);
        expect(mockSettingsNotifier.state.userRelays, isEmpty);
      });

      test('switch to same node does not reset relays', () async {
        final notifier = createNotifier();
        await notifier.init();

        // Pre-populate blacklist and userRelays
        mockSettingsNotifier.state = makeSettings(
          blacklistedRelays: ['wss://relay1.example.com'],
          userRelays: [
            {'url': 'wss://myrelay.example.com'}
          ],
        );

        // Select the same node that's already active
        await notifier.selectNode(trustedPubkey);

        // Relays should be preserved
        expect(
          mockSettingsNotifier.state.blacklistedRelays,
          ['wss://relay1.example.com'],
        );
        expect(mockSettingsNotifier.state.userRelays, [
          {'url': 'wss://myrelay.example.com'}
        ]);
      });

      test('selectNode with unknown pubkey is a no-op', () async {
        final notifier = createNotifier();
        await notifier.init();

        final stateBefore = mockSettingsNotifier.state;

        await notifier.selectNode(
          'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
        );

        // Settings should be completely unchanged
        expect(mockSettingsNotifier.state.mostroPublicKey,
            stateBefore.mostroPublicKey);
        expect(mockSettingsNotifier.state.blacklistedRelays,
            stateBefore.blacklistedRelays);
        expect(
            mockSettingsNotifier.state.userRelays, stateBefore.userRelays);
      });
    });

    group('Custom node lifecycle', () {
      test('add → select → verify full flow', () async {
        final notifier = createNotifier();
        await notifier.init();

        // Add custom node
        final added =
            await notifier.addCustomNode(customPubkeyA, name: 'My Node');
        expect(added, true);

        // Select it
        await notifier.selectNode(customPubkeyA);

        // Verify selectedNode returns the custom node (dynamic ref reads
        // updated state after updateMostroInstance)
        expect(notifier.selectedNode, isNotNull);
        expect(notifier.selectedNode!.pubkey, customPubkeyA);
        expect(notifier.selectedNode!.name, 'My Node');
        expect(notifier.selectedNode!.isTrusted, false);

        // Verify settings match
        expect(
          mockSettingsNotifier.state.mostroPublicKey,
          customPubkeyA,
        );
      });

      test('add → remove (not active) succeeds', () async {
        final notifier = createNotifier();
        await notifier.init();

        await notifier.addCustomNode(customPubkeyA, name: 'Temp Node');
        expect(notifier.customNodes.length, 1);

        final removed = await notifier.removeCustomNode(customPubkeyA);
        expect(removed, true);
        expect(notifier.customNodes, isEmpty);
      });

      test('add → select → attempt remove (active) fails', () async {
        final notifier = createNotifier();
        await notifier.init();

        await notifier.addCustomNode(customPubkeyA, name: 'Active Node');
        await notifier.selectNode(customPubkeyA);

        // removeCustomNode reads settings dynamically to check active pubkey
        final removed = await notifier.removeCustomNode(customPubkeyA);
        expect(removed, false);
        expect(notifier.customNodes.length, 1);
        expect(notifier.customNodes.first.pubkey, customPubkeyA);
      });

      test('addCustomNode rejects duplicate in multi-step flow', () async {
        final notifier = createNotifier();
        await notifier.init();

        final added1 =
            await notifier.addCustomNode(customPubkeyA, name: 'First');
        expect(added1, true);
        expect(notifier.customNodes.length, 1);

        // Attempt to add same pubkey again
        final added2 =
            await notifier.addCustomNode(customPubkeyA, name: 'Duplicate');
        expect(added2, false);
        // No duplication
        expect(notifier.customNodes.length, 1);
        expect(notifier.customNodes.first.name, 'First');
      });
    });

    group('Backward compatibility', () {
      test('unrecognized pubkey auto-imported as custom node', () async {
        const unknownPubkey =
            'aabbccdd11223344aabbccdd11223344aabbccdd11223344aabbccdd11223344';
        mockSettingsNotifier.state =
            makeSettings(mostroPublicKey: unknownPubkey);

        final notifier = createNotifier();
        await notifier.init();

        // Verify auto-imported
        expect(notifier.customNodes.length, 1);
        expect(notifier.customNodes.first.pubkey, unknownPubkey);
        expect(notifier.customNodes.first.isTrusted, false);

        // Verify persisted via in-memory storage
        final savedJson =
            storage[SharedPreferencesKeys.mostroCustomNodes.value];
        expect(savedJson, isNotNull);
        final decoded = jsonDecode(savedJson!) as List<dynamic>;
        expect(decoded.length, 1);
        expect(
          (decoded.first as Map<String, dynamic>)['pubkey'],
          unknownPubkey,
        );
      });

      test('malformed pubkey silently ignored', () async {
        mockSettingsNotifier.state =
            makeSettings(mostroPublicKey: 'not-hex');

        final notifier = createNotifier();
        await notifier.init();

        expect(notifier.customNodes, isEmpty);
        // Should still have trusted nodes, no crash
        expect(
          notifier.trustedNodes.length,
          Config.trustedMostroNodes.length,
        );
      });

      test('trusted node pubkey not duplicated in custom nodes', () async {
        // Settings already default to trustedPubkey via makeSettings()
        final notifier = createNotifier();
        await notifier.init();

        expect(notifier.customNodes, isEmpty);
        // Trusted node should exist exactly once
        expect(
          notifier.state.where((n) => n.pubkey == trustedPubkey).length,
          1,
        );
      });

      test('empty mostroPublicKey results in null selectedNode', () async {
        mockSettingsNotifier.state = makeSettings(mostroPublicKey: '');

        final notifier = createNotifier();
        await notifier.init();

        expect(notifier.selectedNode, isNull);
        // No custom nodes auto-imported for empty string
        expect(notifier.customNodes, isEmpty);
      });
    });

    group('Settings persistence across restart', () {
      test('custom nodes survive restart via shared preferences', () async {
        // First session: init and add custom node
        final notifier1 = createNotifier();
        await notifier1.init();
        await notifier1.addCustomNode(customPubkeyA, name: 'Persistent Node');
        expect(notifier1.customNodes.length, 1);

        // Verify data was written to in-memory storage
        expect(
          storage[SharedPreferencesKeys.mostroCustomNodes.value],
          isNotNull,
        );

        // Second session: create new notifier with same prefs (same storage)
        final notifier2 = createNotifier();
        await notifier2.init();

        expect(notifier2.customNodes.length, 1);
        expect(notifier2.customNodes.first.pubkey, customPubkeyA);
        expect(notifier2.customNodes.first.name, 'Persistent Node');
      });

      test('selectNode updates settings notifier state', () async {
        final notifier = createNotifier();
        await notifier.init();
        await notifier.addCustomNode(customPubkeyA, name: 'Selected Node');

        await notifier.selectNode(customPubkeyA);

        // Verify MockSettingsNotifier in-memory state was updated
        expect(
          mockSettingsNotifier.state.mostroPublicKey,
          customPubkeyA,
        );
      });

      test('corrupt SharedPreferences handled gracefully', () async {
        // Seed with invalid JSON
        storage[SharedPreferencesKeys.mostroCustomNodes.value] =
            'not valid json{{{';

        final notifier = createNotifier();
        await notifier.init();

        // Should still have trusted nodes, no custom, no crash
        expect(
          notifier.trustedNodes.length,
          Config.trustedMostroNodes.length,
        );
        expect(notifier.customNodes, isEmpty);
      });
    });

    group('Relay reconnection after node switch', () {
      test('blacklisted relays cleared on switch to different node', () async {
        final notifier = createNotifier();
        await notifier.init();
        await notifier.addCustomNode(customPubkeyA, name: 'Node A');

        // Pre-populate blacklist
        mockSettingsNotifier.state = mockSettingsNotifier.state.copyWith(
          blacklistedRelays: [
            'wss://relay1.example.com',
            'wss://relay2.example.com',
          ],
        );

        // Switch to custom node (different from trusted -> triggers reset)
        await notifier.selectNode(customPubkeyA);

        expect(mockSettingsNotifier.state.blacklistedRelays, isEmpty);
      });

      test('user relays cleared on switch to different node', () async {
        final notifier = createNotifier();
        await notifier.init();
        await notifier.addCustomNode(customPubkeyA, name: 'Node A');

        // Pre-populate user relays
        mockSettingsNotifier.state = mockSettingsNotifier.state.copyWith(
          userRelays: [
            {'url': 'wss://myrelay1.example.com'},
            {'url': 'wss://myrelay2.example.com'},
          ],
        );

        // Switch to custom node
        await notifier.selectNode(customPubkeyA);

        expect(mockSettingsNotifier.state.userRelays, isEmpty);
      });

      test('main relays list preserved on node switch', () async {
        final notifier = createNotifier();
        await notifier.init();
        await notifier.addCustomNode(customPubkeyA, name: 'Node A');

        final expectedRelays = [
          'wss://relay1.example.com',
          'wss://relay2.example.com',
        ];
        mockSettingsNotifier.state = mockSettingsNotifier.state.copyWith(
          relays: expectedRelays,
          blacklistedRelays: ['wss://blocked.example.com'],
        );

        // Switch to custom node — blacklist/userRelays reset but relays preserved
        await notifier.selectNode(customPubkeyA);

        expect(mockSettingsNotifier.state.relays, expectedRelays);
        expect(mockSettingsNotifier.state.blacklistedRelays, isEmpty);
      });

      test('same node preserves relays', () async {
        final notifier = createNotifier();
        await notifier.init();

        final expectedBlacklist = ['wss://relay1.example.com'];
        final expectedUserRelays = [
          {'url': 'wss://myrelay.example.com'}
        ];

        // Pre-populate relays
        mockSettingsNotifier.state = makeSettings(
          blacklistedRelays: expectedBlacklist,
          userRelays: expectedUserRelays,
        );

        // Select same trusted node
        await notifier.selectNode(trustedPubkey);

        expect(
          mockSettingsNotifier.state.blacklistedRelays,
          expectedBlacklist,
        );
        expect(
          mockSettingsNotifier.state.userRelays,
          expectedUserRelays,
        );
      });
    });

    group('Pubkey case sensitivity', () {
      test('addCustomNode treats different case as different pubkey', () async {
        final notifier = createNotifier();
        await notifier.init();

        // Add with lowercase
        final added = await notifier.addCustomNode(
          customPubkeyA.toLowerCase(),
          name: 'Lowercase',
        );
        expect(added, true);

        // Uppercase variant is treated as different pubkey because
        // MostroNode uses exact string comparison for equality
        final addedUpper = await notifier.addCustomNode(
          customPubkeyA.toUpperCase(),
          name: 'Uppercase',
        );

        expect(addedUpper, true);
        expect(notifier.customNodes.length, 2);
      });
    });

    group('Multi-step end-to-end flows', () {
      test('add multiple custom nodes, switch between them, remove one',
          () async {
        final notifier = createNotifier();
        await notifier.init();

        // Add two custom nodes
        await notifier.addCustomNode(customPubkeyA, name: 'Node A');
        await notifier.addCustomNode(customPubkeyB, name: 'Node B');
        expect(notifier.customNodes.length, 2);

        // Switch to Node A
        await notifier.selectNode(customPubkeyA);
        expect(
          mockSettingsNotifier.state.mostroPublicKey,
          customPubkeyA,
        );

        // Cannot remove active Node A
        expect(await notifier.removeCustomNode(customPubkeyA), false);

        // Can remove inactive Node B
        expect(await notifier.removeCustomNode(customPubkeyB), true);
        expect(notifier.customNodes.length, 1);
        expect(notifier.customNodes.first.pubkey, customPubkeyA);

        // Switch back to trusted
        await notifier.selectNode(trustedPubkey);
        expect(
          mockSettingsNotifier.state.mostroPublicKey,
          trustedPubkey,
        );

        // Now can remove Node A since it's no longer active
        expect(await notifier.removeCustomNode(customPubkeyA), true);
        expect(notifier.customNodes, isEmpty);
      });

      test('persistence round-trip with multiple nodes', () async {
        // Session 1: add two custom nodes
        final notifier1 = createNotifier();
        await notifier1.init();
        await notifier1.addCustomNode(customPubkeyA, name: 'Node A');
        await notifier1.addCustomNode(customPubkeyB, name: 'Node B');

        // Session 2: verify both nodes persisted
        final notifier2 = createNotifier();
        await notifier2.init();
        expect(notifier2.customNodes.length, 2);

        final pubkeys = notifier2.customNodes.map((n) => n.pubkey).toSet();
        expect(pubkeys, contains(customPubkeyA));
        expect(pubkeys, contains(customPubkeyB));

        // Remove one node in session 2
        await notifier2.removeCustomNode(customPubkeyA);

        // Session 3: verify removal persisted
        final notifier3 = createNotifier();
        await notifier3.init();
        expect(notifier3.customNodes.length, 1);
        expect(notifier3.customNodes.first.pubkey, customPubkeyB);
      });
    });
  });
}
