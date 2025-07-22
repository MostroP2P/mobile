import 'dart:async';
import 'dart:convert';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/enums/role.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/key_manager/key_manager.dart';
import 'package:mostro_mobile/services/nostr_service.dart';

/// Service to efficiently restore trade history when importing a mnemonic
class TradeHistoryRestorationService {
  final KeyManager _keyManager;
  final NostrService _nostrService;
  final Logger _logger = Logger();

  TradeHistoryRestorationService(
    this._keyManager,
    this._nostrService,
  );

  /// Restore trade history by scanning for used trade keys and subscribing to them
  /// Returns the highest trade key index found with messages
  Future<(int, Map<String, Session>)> restoreTradeHistory({
    int maxKeysToScan = 100,
    int batchSize = 20,
  }) async {
    _logger.i('Starting trade history restoration...');

    // Guard against null master key pair
    if (_keyManager.masterKeyPair == null) {
      _logger.e('Master key pair is null, cannot restore trade history');
      throw Exception(
          'Master key pair not available for trade history restoration');
    }

    int highestUsedIndex = 0;
    final sessions = <String, Session>{};
    final usedTradeKeys = <int, String>{};

    try {
      // Scan in batches to avoid overwhelming relays
      for (int startIndex = 1;
          startIndex <= maxKeysToScan;
          startIndex += batchSize) {
        final endIndex = (startIndex + batchSize - 1).clamp(1, maxKeysToScan);

        _logger.i('Scanning trade keys $startIndex to $endIndex...');

        // Generate batch of trade keys
        final batchKeys = _keyManager.generateTradeKeyBatch(
            startIndex, endIndex - startIndex + 1);

        // Query relays for messages to these keys
        final batchSessions = await _queryRelaysForKeys(
            Map<int, NostrKeyPairs>.fromEntries(batchKeys),
            since: DateTime.now().subtract(
              Duration(
                hours: Config.tradeHistoryScanHours,
              ),
            ));

        // Track which keys have messages
        for (final entry in batchKeys) {
          if (batchSessions.containsKey(entry.value.public)) {
            usedTradeKeys[entry.key] = entry.value.public;
            highestUsedIndex =
                entry.key > highestUsedIndex ? entry.key : highestUsedIndex;
            _logger.i('Found messages for trade key index ${entry.key}');
          }
        }
        sessions.addAll(batchSessions);

        // If we found no keys in this batch, we might be done
        if (batchSessions.isEmpty && startIndex > 20) {
          _logger.i(
              'No messages found in batch $startIndex-$endIndex, stopping scan');
          break;
        } else {
          _logger.i(
              'Found ${batchSessions.length} messages in batch $startIndex-$endIndex');
        }

        // Small delay between batches to be nice to relays
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Subscribe to all found trade keys
      if (usedTradeKeys.isNotEmpty) {
        // Update the trade key index to be one higher than the highest used
        await _keyManager.setCurrentKeyIndex(highestUsedIndex + 1);

        _logger.i(
            'Trade history restoration complete. Found ${usedTradeKeys.length} used keys, set index to ${highestUsedIndex + 1}');
      } else {
        _logger.i('No trade history found, keeping default key index');
      }

      return (highestUsedIndex, sessions);
    } catch (e) {
      _logger.e('Error during trade history restoration: $e');
      rethrow;
    }
  }

  /// Query relays for messages addressed to the given public keys
  /// Returns a set of public keys that have messages
  Future<Map<String, Session>> _queryRelaysForKeys(
      Map<int, NostrKeyPairs> publicKeys,
      {DateTime? since}) async {
    final sessions = <String, Session>{};

    // Create lookup map to avoid concurrent modification during iteration
    final publicKeyLookup = <String, MapEntry<int, NostrKeyPairs>>{};
    for (final entry in publicKeys.entries) {
      publicKeyLookup[entry.value.public] = entry;
    }

    final filter = NostrFilter(
      kinds: [1059],
      p: publicKeyLookup.keys.toList(),
      since: since,
      limit: 100,
    );

    final events = await _nostrService.fetchEvents(filter);

    for (final event in events) {
      if (event.recipient != null &&
          publicKeyLookup.containsKey(event.recipient)) {
        final pkey = publicKeyLookup[event.recipient]!;
        final decryptedEvent = await event.unWrap(
          pkey.value.private,
        );
        if (decryptedEvent.content == null) continue;

        final result = jsonDecode(decryptedEvent.content!);
        if (result is! List) continue;

        final msg = MostroMessage.fromJson(result[0]);
        if (msg.tradeIndex != null && msg.tradeIndex != pkey.key) {
          _logger.i(
              'Trade index ${msg.tradeIndex} does not match key index ${pkey.key}');
          continue;
        }

        if (msg.action != Action.newOrder &&
            msg.action != Action.takeBuy &&
            msg.action != Action.takeSell) {
          _logger.i(
              'Message action ${msg.action} is not newOrder, takeBuy or takeSell');
          continue;
        }
        final order = msg.getPayload<Order>();

        if (order == null) {
          _logger.i('Message payload is not an Order');
          continue;
        }

        Role role;
        switch (msg.action) {
          case Action.newOrder:
            role = order.kind == OrderType.buy ? Role.buyer : Role.seller;
            break;
          case Action.takeBuy:
            role = Role.buyer;
            break;
          case Action.takeSell:
            role = Role.seller;
            break;
          default:
            _logger.i(
                'Message action ${msg.action} is not newOrder, takeBuy or takeSell');
            continue;
        }

        final session = Session(
          tradeKey: pkey.value,
          fullPrivacy: msg.tradeIndex == null ? true : false,
          masterKey: _keyManager.masterKeyPair ?? (throw Exception('Master key pair is null')),
          keyIndex: msg.tradeIndex ?? pkey.key,
          startTime: decryptedEvent.createdAt ?? DateTime.now(),
          orderId: msg.id,
          role: role,
        );

        sessions[pkey.value.public] = session;
        _logger.i(
            'Created session for order ${msg.id} with trade index ${msg.tradeIndex}');
      }
    }
    return sessions;
  }
}
