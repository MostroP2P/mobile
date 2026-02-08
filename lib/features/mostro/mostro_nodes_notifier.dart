import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/data/models/enums/storage_keys.dart';
import 'package:mostro_mobile/features/mostro/mostro_node.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MostroNodesNotifier extends StateNotifier<List<MostroNode>> {
  final SharedPreferencesAsync _prefs;
  final Ref _ref;

  MostroNodesNotifier(this._prefs, this._ref) : super([]);

  Future<void> init() async {
    final trustedNodes = Config.trustedMostroNodes.map((entry) {
      return MostroNode(
        pubkey: entry['pubkey']!,
        name: entry['name'],
        isTrusted: true,
      );
    }).toList();

    final customNodes = await _loadCustomNodes();

    // Backward compatibility: if the current mostroPublicKey doesn't match
    // any trusted or custom node, auto-import it as a custom node
    final currentPubkey = _ref.read(settingsProvider).mostroPublicKey;
    final allPubkeys = {
      ...trustedNodes.map((n) => n.pubkey),
      ...customNodes.map((n) => n.pubkey),
    };

    if (currentPubkey.isNotEmpty &&
        !allPubkeys.contains(currentPubkey) &&
        _isValidHexPubkey(currentPubkey)) {
      logger.i(
        'Current pubkey not found in known nodes, auto-importing as custom',
      );
      final importedNode = MostroNode(
        pubkey: currentPubkey,
        addedAt: DateTime.now(),
      );
      customNodes.add(importedNode);
      await _saveCustomNodes(customNodes);
    }

    state = [...trustedNodes, ...customNodes];
    logger.i(
      'MostroNodesNotifier initialized: '
      '${trustedNodes.length} trusted, ${customNodes.length} custom',
    );
  }

  /// Get the currently selected node based on settings
  MostroNode? get selectedNode {
    final currentPubkey = _ref.read(settingsProvider).mostroPublicKey;
    for (final node in state) {
      if (node.pubkey == currentPubkey) return node;
    }
    return null;
  }

  /// Select a node and trigger the existing Mostro instance switch
  Future<void> selectNode(String pubkey) async {
    MostroNode? node;
    for (final n in state) {
      if (n.pubkey == pubkey) {
        node = n;
        break;
      }
    }
    if (node == null) {
      logger.w('Cannot select unknown node: $pubkey');
      return;
    }

    await _ref.read(settingsProvider.notifier).updateMostroInstance(pubkey);
    logger.i('Selected Mostro node: ${node.displayName}');
  }

  /// Add a custom node with duplicate check
  Future<bool> addCustomNode(String pubkey, {String? name}) async {
    if (state.any((n) => n.pubkey == pubkey)) {
      logger.w('Node with pubkey $pubkey already exists');
      return false;
    }

    if (!_isValidHexPubkey(pubkey)) {
      logger.w('Invalid pubkey format: $pubkey');
      return false;
    }

    final newNode = MostroNode(
      pubkey: pubkey,
      name: name,
      addedAt: DateTime.now(),
    );

    final updatedCustom = [...customNodes, newNode];
    final saved = await _saveCustomNodes(updatedCustom);
    if (!saved) return false;
    state = [...trustedNodes, ...updatedCustom];
    logger.i('Added custom Mostro node: ${newNode.displayName}');
    return true;
  }

  /// Remove a custom node (cannot remove trusted nodes)
  Future<bool> removeCustomNode(String pubkey) async {
    MostroNode? node;
    for (final n in state) {
      if (n.pubkey == pubkey) {
        node = n;
        break;
      }
    }
    if (node == null || node.isTrusted) {
      logger.w('Cannot remove node: $pubkey (not found or trusted)');
      return false;
    }

    final currentPubkey = _ref.read(settingsProvider).mostroPublicKey;
    if (pubkey == currentPubkey) {
      logger.w('Cannot remove currently active node');
      return false;
    }

    final updatedCustom = customNodes.where((n) => n.pubkey != pubkey).toList();
    final saved = await _saveCustomNodes(updatedCustom);
    if (!saved) return false;
    state = [...trustedNodes, ...updatedCustom];
    logger.i('Removed custom Mostro node: ${node.displayName}');
    return true;
  }

  /// Update custom node name
  Future<bool> updateCustomNodeName(String pubkey, String newName) async {
    if (!customNodes.any((n) => n.pubkey == pubkey)) {
      logger.w('Cannot update name: custom node $pubkey not found');
      return false;
    }
    final updatedCustom = customNodes.map((n) {
      if (n.pubkey == pubkey) {
        return n.withMetadata(name: newName);
      }
      return n;
    }).toList();
    final saved = await _saveCustomNodes(updatedCustom);
    if (!saved) return false;
    state = [
      ...trustedNodes,
      ...updatedCustom,
    ];
    return true;
  }

  /// Update node metadata (from kind 0 fetch in Phase 2)
  void updateNodeMetadata(
    String pubkey, {
    String? name,
    String? picture,
    String? website,
    String? about,
  }) {
    state = state.map((n) {
      if (n.pubkey == pubkey) {
        return n.withMetadata(
          name: name,
          picture: picture,
          website: website,
          about: about,
        );
      }
      return n;
    }).toList();
  }

  /// Check if a pubkey belongs to a trusted node
  bool isTrustedNode(String pubkey) {
    return state.any((n) => n.pubkey == pubkey && n.isTrusted);
  }

  List<MostroNode> get trustedNodes => state.where((n) => n.isTrusted).toList();

  List<MostroNode> get customNodes => state.where((n) => !n.isTrusted).toList();

  static final _hexPubkeyRegex = RegExp(r'^[0-9a-fA-F]{64}$');

  static bool _isValidHexPubkey(String value) {
    return _hexPubkeyRegex.hasMatch(value);
  }

  Future<List<MostroNode>> _loadCustomNodes() async {
    try {
      final json = await _prefs.getString(
        SharedPreferencesKeys.mostroCustomNodes.value,
      );
      if (json == null) return [];

      final list = jsonDecode(json) as List<dynamic>;
      return list
          .map((e) => MostroNode.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      logger.e('Failed to load custom nodes: $e');
      return [];
    }
  }

  Future<bool> _saveCustomNodes(List<MostroNode> nodes) async {
    try {
      final json = jsonEncode(nodes.map((n) => n.toJson()).toList());
      await _prefs.setString(
        SharedPreferencesKeys.mostroCustomNodes.value,
        json,
      );
      return true;
    } catch (e) {
      logger.e('Failed to save custom nodes: $e');
      return false;
    }
  }
}
