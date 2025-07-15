import 'dart:async';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
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
  Future<int> restoreTradeHistory({
    int maxKeysToScan = 100,
    int batchSize = 20,
    Duration timeoutPerBatch = const Duration(seconds: 10),
  }) async {
    _logger.i('Starting trade history restoration...');

    int highestUsedIndex = 0;
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
        final publicKeys =
            batchKeys.map((entry) => entry.value.public).toList();

        // Query relays for messages to these keys
        final keysWithMessages = await _queryRelaysForKeys(publicKeys);

        // Track which keys have messages
        for (final entry in batchKeys) {
          if (keysWithMessages.contains(entry.value.public)) {
            usedTradeKeys[entry.key] = entry.value.public;
            highestUsedIndex =
                entry.key > highestUsedIndex ? entry.key : highestUsedIndex;
            _logger.i('Found messages for trade key index ${entry.key}');
          }
        }

        // If we found no keys in this batch, we might be done
        if (keysWithMessages.isEmpty && startIndex > 20) {
          _logger.i(
              'No messages found in batch $startIndex-$endIndex, stopping scan');
          break;
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

      return highestUsedIndex;
    } catch (e) {
      _logger.e('Error during trade history restoration: $e');
      rethrow;
    }
  }

  /// Query relays for messages addressed to the given public keys
  /// Returns a set of public keys that have messages
  Future<Set<String>> _queryRelaysForKeys(List<String> publicKeys) async {
    final keysWithMessages = <String>{};

    final filter = NostrFilter(
      kinds: [1059],
      p: publicKeys,
      since: DateTime.now().subtract(const Duration(hours: 72)),
      limit: 100,
    );

    final events = await _nostrService.fetchEvents(filter);
    for (final event in events) {
      if (publicKeys.contains(event.recipient!)) {
        keysWithMessages.add(event.recipient!);
      }
    }

    return keysWithMessages;
  }

}
