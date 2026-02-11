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

/// Generates a deterministic 64-char hex pubkey from an integer index.
String makePubkey(int i) => i.toRadixString(16).padLeft(64, '0');

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
  const nodeCount = 50;

  group('Performance with many custom nodes', () {
    late MockSharedPreferencesAsync mockPrefs;
    late MockRef mockRef;
    late MockSettingsNotifier mockSettingsNotifier;
    late Map<String, String> storage;

    setUp(() {
      mockPrefs = MockSharedPreferencesAsync();
      mockRef = MockRef();
      mockSettingsNotifier = MockSettingsNotifier();
      storage = <String, String>{};

      when(mockPrefs.getString(any)).thenAnswer(
          (inv) async => storage[inv.positionalArguments[0] as String]);
      when(mockPrefs.setString(any, any)).thenAnswer((inv) async {
        storage[inv.positionalArguments[0] as String] =
            inv.positionalArguments[1] as String;
      });

      mockSettingsNotifier.state = Settings(
        relays: ['wss://default.example.com'],
        fullPrivacyMode: false,
        mostroPublicKey: trustedPubkey,
      );

      when(mockRef.read(settingsProvider))
          .thenAnswer((_) => mockSettingsNotifier.state);
      when(mockRef.read(settingsProvider.notifier))
          .thenReturn(mockSettingsNotifier);
    });

    MostroNodesNotifier createNotifier() {
      return MostroNodesNotifier(mockPrefs, mockRef);
    }

    test('add $nodeCount custom nodes and verify all persisted', () async {
      final notifier = createNotifier();
      await notifier.init();

      // Add 50 custom nodes
      for (var i = 0; i < nodeCount; i++) {
        final result =
            await notifier.addCustomNode(makePubkey(i), name: 'Node $i');
        expect(result, true, reason: 'Failed to add node $i');
      }

      // Verify state has trusted + custom nodes
      final trustedCount = Config.trustedMostroNodes.length;
      expect(notifier.state.length, trustedCount + nodeCount);
      expect(notifier.customNodes.length, nodeCount);
      expect(notifier.trustedNodes.length, trustedCount);

      // Verify persistence: create a new notifier with same backing store
      final notifier2 = createNotifier();
      await notifier2.init();
      expect(notifier2.customNodes.length, nodeCount);

      // Verify all pubkeys are present and unique
      final pubkeys = notifier2.customNodes.map((n) => n.pubkey).toSet();
      expect(pubkeys.length, nodeCount);
      for (var i = 0; i < nodeCount; i++) {
        expect(pubkeys, contains(makePubkey(i)));
      }
    });

    test('selectedNode lookup with last node in large list', () async {
      final notifier = createNotifier();
      await notifier.init();

      // Add 50 custom nodes
      for (var i = 0; i < nodeCount; i++) {
        await notifier.addCustomNode(makePubkey(i), name: 'Node $i');
      }

      // Select the last custom node
      final lastPubkey = makePubkey(nodeCount - 1);
      await notifier.selectNode(lastPubkey);

      expect(notifier.selectedNode, isNotNull);
      expect(notifier.selectedNode!.pubkey, lastPubkey);
      expect(notifier.selectedNode!.name, 'Node ${nodeCount - 1}');
      expect(mockSettingsNotifier.state.mostroPublicKey, lastPubkey);
    });

    test('remove node from middle of large list', () async {
      final notifier = createNotifier();
      await notifier.init();

      // Add 50 custom nodes
      for (var i = 0; i < nodeCount; i++) {
        await notifier.addCustomNode(makePubkey(i), name: 'Node $i');
      }

      // Remove node from the middle (node 25)
      final middleIndex = nodeCount ~/ 2;
      final middlePubkey = makePubkey(middleIndex);
      final result = await notifier.removeCustomNode(middlePubkey);
      expect(result, true);

      // Verify list integrity
      expect(notifier.customNodes.length, nodeCount - 1);
      expect(
        notifier.customNodes.any((n) => n.pubkey == middlePubkey),
        false,
        reason: 'Removed node should not be in list',
      );

      // Verify surrounding nodes still present
      expect(
        notifier.customNodes.any((n) => n.pubkey == makePubkey(middleIndex - 1)),
        true,
      );
      expect(
        notifier.customNodes.any((n) => n.pubkey == makePubkey(middleIndex + 1)),
        true,
      );

      // Verify persistence after removal
      final notifier2 = createNotifier();
      await notifier2.init();
      expect(notifier2.customNodes.length, nodeCount - 1);
      expect(
        notifier2.customNodes.any((n) => n.pubkey == middlePubkey),
        false,
      );
    });

    test('batch metadata update for all nodes', () async {
      final notifier = createNotifier();
      await notifier.init();

      // Add 50 custom nodes
      for (var i = 0; i < nodeCount; i++) {
        await notifier.addCustomNode(makePubkey(i), name: 'Node $i');
      }

      final totalNodes = notifier.state.length;

      // Update metadata for every node (trusted + custom)
      for (final node in notifier.state) {
        notifier.updateNodeMetadata(
          node.pubkey,
          name: 'Updated ${node.pubkey.substring(0, 8)}',
          picture: 'https://example.com/avatar/${node.pubkey.substring(0, 8)}.png',
          about: 'About node ${node.pubkey.substring(0, 8)}',
        );
      }

      // Verify all nodes updated
      expect(notifier.state.length, totalNodes);
      for (final node in notifier.state) {
        expect(node.name, startsWith('Updated '));
        expect(node.picture, startsWith('https://'));
        expect(node.about, startsWith('About node '));
      }

      // Verify trusted node metadata updated too
      final trustedNode =
          notifier.state.firstWhere((n) => n.pubkey == trustedPubkey);
      expect(trustedNode.name, startsWith('Updated '));
      expect(trustedNode.picture, isNotNull);
    });

    test('init with $nodeCount pre-existing nodes completes promptly',
        () async {
      // Pre-populate storage with 50 custom nodes (simulating existing data)
      final notifier1 = createNotifier();
      await notifier1.init();
      for (var i = 0; i < nodeCount; i++) {
        await notifier1.addCustomNode(makePubkey(i), name: 'Existing $i');
      }

      // Verify storage was populated
      expect(
        storage[SharedPreferencesKeys.mostroCustomNodes.value],
        isNotNull,
      );

      // Measure init with many pre-existing nodes
      final stopwatch = Stopwatch()..start();
      final notifier2 = createNotifier();
      await notifier2.init();
      stopwatch.stop();

      // Verify all loaded correctly
      expect(notifier2.customNodes.length, nodeCount);
      expect(notifier2.state.length,
          Config.trustedMostroNodes.length + nodeCount);

      // Sanity check: init should complete in well under 1 second
      expect(stopwatch.elapsedMilliseconds, lessThan(1000),
          reason: 'init() with $nodeCount nodes took too long: '
              '${stopwatch.elapsedMilliseconds}ms');
    });
  });
}
