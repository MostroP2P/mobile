import 'dart:convert';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/data/models/enums/storage_keys.dart';
import 'package:mostro_mobile/features/mostro/mostro_node.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MostroNodesNotifier extends StateNotifier<List<MostroNode>> {
  final SharedPreferencesAsync _prefs;
  final Ref _ref;

  /// In-memory metadata cache for all nodes (trusted + custom).
  /// Loaded once during init(), updated in-place, and persisted atomically
  /// to avoid race conditions from concurrent fire-and-forget writes.
  Map<String, Map<String, dynamic>> _metadataCache = {};

  MostroNodesNotifier(this._prefs, this._ref) : super([]);

  Future<void> init() async {
    // Load cached metadata so trusted nodes have their last-known
    // kind 0 data available immediately (before any relay fetch).
    _metadataCache = await _loadMetadataCache();

    final trustedNodes = Config.trustedMostroNodes.map((entry) {
      final pubkey = entry['pubkey']!;
      final cached = _metadataCache[pubkey];
      return MostroNode(
        pubkey: pubkey,
        name: cached?['name'] as String? ?? entry['name'],
        picture: cached?['picture'] as String? ?? entry['picture'],
        website: cached?['website'] as String? ?? entry['website'],
        about: cached?['about'] as String? ?? entry['about'],
        isTrusted: true,
      );
    }).toList();

    var customNodes = await _loadCustomNodes();

    // Remove custom nodes that overlap with trusted nodes (one-time migration)
    final trustedPubkeys = trustedNodes.map((n) => n.pubkey).toSet();
    final cleanedCustomNodes =
        customNodes.where((n) => !trustedPubkeys.contains(n.pubkey)).toList();
    if (cleanedCustomNodes.length != customNodes.length) {
      logger.i(
        'Removed ${customNodes.length - cleanedCustomNodes.length} '
        'custom node(s) that overlap with trusted nodes',
      );
      await _saveCustomNodes(cleanedCustomNodes);
      customNodes = cleanedCustomNodes;
    }

    // Backward compatibility: if the current mostroPublicKey doesn't match
    // any trusted or custom node, auto-import it as a custom node
    final currentPubkey = _ref.read(settingsProvider).mostroPublicKey;
    final allPubkeys = {
      ...trustedPubkeys,
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
    pubkey = pubkey.toLowerCase();
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
    pubkey = pubkey.toLowerCase();
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

    // Persist metadata for custom nodes so it survives app restart
    _saveCustomNodes(customNodes);

    // Cache metadata for all nodes (including trusted) so it survives restart
    _updateMetadataCache(pubkey, name, picture, website, about);
  }

  /// Fetch kind 0 metadata for all nodes in a single batch request
  Future<void> fetchAllNodeMetadata() async {
    final pubkeys = state.map((n) => n.pubkey).toList();
    if (pubkeys.isEmpty) return;

    try {
      final nostrService = _ref.read(nostrServiceProvider);
      final filter = NostrFilter(kinds: const [0], authors: pubkeys);
      final events = await nostrService.fetchEvents(filter);
      if (!mounted) return;

      // Deduplicate: keep most recent event per pubkey
      final latestByPubkey = <String, NostrEvent>{};
      for (final event in events) {
        final existing = latestByPubkey[event.pubkey];
        if (existing == null ||
            (event.createdAt?.isAfter(existing.createdAt ?? DateTime(0)) ??
                false)) {
          latestByPubkey[event.pubkey] = event;
        }
      }

      logger.i(
        'Fetched kind 0 metadata for ${latestByPubkey.length}/${pubkeys.length} nodes',
      );
      for (final event in latestByPubkey.values) {
        _applyMetadataFromEvent(event);
      }
    } catch (e) {
      logger.e('Failed to fetch node metadata: $e');
    }
  }

  /// Fetch kind 0 metadata for a single node
  Future<void> fetchNodeMetadata(String pubkey) async {
    try {
      final nostrService = _ref.read(nostrServiceProvider);
      final filter =
          NostrFilter(kinds: const [0], authors: [pubkey], limit: 1);
      final events = await nostrService.fetchEvents(filter);
      if (!mounted || events.isEmpty) return;

      // Deduplicate: limit is a relay hint, multiple relays may return events
      var latest = events.first;
      for (var i = 1; i < events.length; i++) {
        final event = events[i];
        if (event.createdAt?.isAfter(latest.createdAt ?? DateTime(0)) ??
            false) {
          latest = event;
        }
      }
      _applyMetadataFromEvent(latest);
    } catch (e) {
      logger.e('Failed to fetch metadata for $pubkey: $e');
    }
  }

  void _applyMetadataFromEvent(NostrEvent event) {
    try {
      if (!event.isVerified()) {
        logger.w('Ignoring unverified kind 0 event for ${event.pubkey}');
        return;
      }
      final json = jsonDecode(event.content ?? '') as Map<String, dynamic>;
      logger.i(
        'Applying metadata for ${event.pubkey.substring(0, 8)}...: '
        'name=${json['name']}, picture=${json['picture'] != null}, '
        'about=${json['about'] != null}',
      );
      updateNodeMetadata(
        event.pubkey,
        name: json['name'] as String?,
        picture: _sanitizeUrl(json['picture'] as String?),
        website: _sanitizeUrl(json['website'] as String?),
        about: json['about'] as String?,
      );
    } catch (e) {
      logger.e('Failed to parse metadata for ${event.pubkey}: $e');
    }
  }

  /// Returns the URL only if it uses the https scheme, otherwise null.
  static String? _sanitizeUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return null;
    return url;
  }

  /// Check if a pubkey belongs to a trusted node
  bool isTrustedNode(String pubkey) {
    return state.any((n) => n.pubkey == pubkey && n.isTrusted);
  }

  List<MostroNode> get trustedNodes => state.where((n) => n.isTrusted).toList();

  List<MostroNode> get customNodes => state.where((n) => !n.isTrusted).toList();

  static bool _isValidHexPubkey(String value) {
    return MostroNode.isValidHexPubkey(value);
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

  /// Load the metadata cache for all nodes (keyed by pubkey).
  Future<Map<String, Map<String, dynamic>>> _loadMetadataCache() async {
    try {
      final json = await _prefs.getString(
        SharedPreferencesKeys.mostroNodeMetadataCache.value,
      );
      if (json == null) return {};

      final decoded = jsonDecode(json) as Map<String, dynamic>;
      return decoded.map(
        (key, value) =>
            MapEntry(key, Map<String, dynamic>.from(value as Map)),
      );
    } catch (e) {
      logger.e('Failed to load metadata cache: $e');
      return {};
    }
  }

  /// Update a single entry in the in-memory metadata cache and persist it.
  ///
  /// Uses the in-memory [_metadataCache] to avoid race conditions from
  /// concurrent reads — all updates go through the same map instance.
  Future<void> _updateMetadataCache(
    String pubkey,
    String? name,
    String? picture,
    String? website,
    String? about,
  ) async {
    try {
      _metadataCache[pubkey] = {
        if (name != null) 'name': name,
        if (picture != null) 'picture': picture,
        if (website != null) 'website': website,
        if (about != null) 'about': about,
      };
      final json = jsonEncode(_metadataCache);
      await _prefs.setString(
        SharedPreferencesKeys.mostroNodeMetadataCache.value,
        json,
      );
    } catch (e) {
      logger.e('Failed to update metadata cache: $e');
    }
  }
}
