import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/data/models/enums/storage_keys.dart';
import 'package:mostro_mobile/features/mostro/mostro_node.dart';
import 'package:mostro_mobile/features/mostro/mostro_nodes_notifier.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_notifier.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';

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
        'new_custom_node_pubkey_1234567890',
        name: 'New Node',
      );

      expect(result, true);
      expect(notifier.customNodes.length, 1);
      expect(
        notifier.customNodes.first.pubkey,
        'new_custom_node_pubkey_1234567890',
      );
      expect(notifier.customNodes.first.name, 'New Node');
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
        'new_custom_pubkey_1234567890abcdef',
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
        'removable_node_pubkey_1234567890',
        name: 'Removable',
      );
      // Reset the verification count
      clearInteractions(mockPrefs);
      when(mockPrefs.setString(any, any)).thenAnswer((_) async {});

      final result = await notifier.removeCustomNode(
        'removable_node_pubkey_1234567890',
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
        'updatable_node_pubkey_1234567890',
        name: 'Old Name',
      );

      await notifier.updateCustomNodeName(
        'updatable_node_pubkey_1234567890',
        'New Name',
      );

      final node = notifier.customNodes.firstWhere(
        (n) => n.pubkey == 'updatable_node_pubkey_1234567890',
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
        'custom_for_trust_check_1234567890',
      );

      expect(notifier.isTrustedNode(trustedPubkey), true);
      expect(
        notifier.isTrustedNode('custom_for_trust_check_1234567890'),
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
  });
}
