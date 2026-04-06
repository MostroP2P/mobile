import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:mostro_mobile/services/logger_service.dart';

/// Repository that fetches community metadata from Nostr relays.
/// Uses a standalone WebSocket connection to fetch kind 0 (profile) and
/// kind 38385 (Mostro info) events without depending on NostrService.
class CommunityRepository {
  static const String _relayUrl = 'wss://relay.mostro.network';
  static const Duration _timeout = Duration(seconds: 10);

  /// Fetches kind 0 and kind 38385 events for the given pubkeys.
  /// Returns a map of pubkey -> CommunityMetadata.
  /// Throws on connection or timeout failures so callers can handle errors.
  Future<Map<String, CommunityMetadata>> fetchCommunityMetadata(
    List<String> pubkeys,
  ) async {
    final results = <String, CommunityMetadata>{};
    for (final pk in pubkeys) {
      results[pk] = CommunityMetadata();
    }

    WebSocket? ws;
    try {
      ws = await WebSocket.connect(_relayUrl).timeout(_timeout);

      final subIdKind0 = _randomSubId();
      final subIdKind38385 = _randomSubId();

      // Send REQ for kind 0
      ws.add(jsonEncode([
        'REQ',
        subIdKind0,
        {
          'kinds': [0],
          'authors': pubkeys,
        },
      ]));

      // Send REQ for kind 38385
      ws.add(jsonEncode([
        'REQ',
        subIdKind38385,
        {
          'kinds': [38385],
          'authors': pubkeys,
          '#y': ['mostro'],
        },
      ]));

      int eoseCount = 0;
      final completer = Completer<void>();

      final subscription = ws.listen(
        (data) {
          try {
            final msg = jsonDecode(data as String) as List<dynamic>;
            if (msg.isEmpty) return;

            final type = msg[0] as String;

            if (type == 'EVENT' && msg.length >= 3) {
              final event = msg[2] as Map<String, dynamic>;
              _processEvent(event, results);
            } else if (type == 'EOSE') {
              eoseCount++;
              if (eoseCount >= 2 && !completer.isCompleted) {
                completer.complete();
              }
            }
          } catch (e) {
            logger.w('Error parsing relay message: $e');
          }
        },
        onError: (e) {
          logger.e('WebSocket error: $e');
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
      );

      await completer.future.timeout(_timeout);

      // Close subscriptions
      ws.add(jsonEncode(['CLOSE', subIdKind0]));
      ws.add(jsonEncode(['CLOSE', subIdKind38385]));
      await subscription.cancel();
    } catch (e) {
      logger.e('Failed to fetch community data: $e');
      rethrow;
    } finally {
      try {
        await ws?.close();
      } catch (_) {}
    }

    return results;
  }

  void _processEvent(
    Map<String, dynamic> event,
    Map<String, CommunityMetadata> results,
  ) {
    final pubkey = event['pubkey'] as String?;
    final kind = event['kind'] as int?;
    if (pubkey == null || kind == null) return;

    final meta = results[pubkey];
    if (meta == null) return;

    final createdAt = event['created_at'] as int? ?? 0;

    if (kind == 0) {
      if (createdAt >= (meta.kind0CreatedAt ?? 0)) {
        try {
          final content =
              jsonDecode(event['content'] as String) as Map<String, dynamic>;
          meta.kind0 = content;
          meta.kind0CreatedAt = createdAt;
        } catch (e) {
          logger.w('Failed to parse kind 0 content for $pubkey: $e');
        }
      }
    } else if (kind == 38385) {
      if (createdAt >= (meta.kind38385CreatedAt ?? 0)) {
        meta.kind38385Tags = _extractTags(event);
        meta.kind38385CreatedAt = createdAt;
      }
    }
  }

  Map<String, String> _extractTags(Map<String, dynamic> event) {
    final tags = event['tags'] as List<dynamic>? ?? [];
    final result = <String, String>{};
    for (final tag in tags) {
      final tagList = tag as List<dynamic>;
      if (tagList.length >= 2) {
        result[tagList[0] as String] = tagList[1] as String;
      }
    }
    return result;
  }

  String _randomSubId() {
    final random = Random();
    return 'community_${random.nextInt(999999).toString().padLeft(6, '0')}';
  }
}

/// Holds fetched metadata for a single community.
class CommunityMetadata {
  Map<String, dynamic>? kind0;
  int? kind0CreatedAt;
  Map<String, String>? kind38385Tags;
  int? kind38385CreatedAt;

  CommunityMetadata();

  String? get name => kind0?['name'] as String?;
  String? get about => kind0?['about'] as String?;
  String? get picture {
    final url = kind0?['picture'] as String?;
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return null;
    return url;
  }

  List<String> get currencies {
    final raw = kind38385Tags?['fiat_currencies_accepted'];
    if (raw == null || raw.isEmpty) return [];
    return raw
        .split(',')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();
  }

  int? get minAmount {
    final raw = kind38385Tags?['min_order_amount'];
    if (raw == null) return null;
    return int.tryParse(raw);
  }

  int? get maxAmount {
    final raw = kind38385Tags?['max_order_amount'];
    if (raw == null) return null;
    return int.tryParse(raw);
  }

  double? get fee {
    final raw = kind38385Tags?['fee'];
    if (raw == null) return null;
    return double.tryParse(raw);
  }
}
