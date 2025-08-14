import 'dart:async';
import 'dart:convert';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/data/models/dispute_event.dart';
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

/// Repository for managing dispute data and events
class DisputeRepository {
  final NostrService _nostrService;
  final String _mostroPubkey;
  final Ref _ref;
  final Logger _logger = Logger();

  DisputeRepository(this._nostrService, this._mostroPubkey, this._ref);


  /// Fetch dispute events from Nostr for the current user
  Future<List<Dispute>> fetchUserDisputes() async {
    try {
      _logger.d('Fetching user disputes from Nostr');

      // Get active sessions to find user's trade keys
      final sessions = _ref.read(sessionNotifierProvider);
      if (sessions.isEmpty) {
        _logger.w('No active sessions found, cannot fetch disputes');
        return [];
      }
      
      // Get all trade key public keys from active sessions
      final userPubkeys = sessions.map((s) => s.tradeKey.public).toList();
      _logger.d('Fetching disputes for user pubkeys: $userPubkeys');

      // Create filter for dispute events from Mostro
      final filter = NostrFilter(
        kinds: [38383], // Dispute event kind
        authors: [_mostroPubkey],
        since: DateTime.now().subtract(const Duration(days: 90)), // Last 90 days
        additionalFilters: {
          '#z': ['dispute'], // Filter for dispute events
        },
      );

      final events = await _nostrService.fetchEvents(filter);
      _logger.d('Fetched ${events.length} dispute events from Mostro');
      
      // Filter events that involve any of the user's pubkeys (from active sessions)
      final userEvents = events.where((event) {
        try {
          final content = jsonDecode(event.content ?? '{}');
          // Check if this dispute involves any of the user's pubkeys
          return userPubkeys.any((pubkey) => 
            content['buyer_pubkey'] == pubkey ||
            content['seller_pubkey'] == pubkey);
        } catch (e) {
          _logger.w('Failed to parse dispute event content: $e');
          return false;
        }
      }).toList();

      // Convert events to Dispute objects
      final disputes = userEvents.map((event) {
        try {
          final content = jsonDecode(event.content ?? '{}');
          return Dispute.fromNostrEvent(event, content);
        } catch (e) {
          _logger.w('Failed to parse dispute event: $e');
          return null;
        }
      }).where((dispute) => dispute != null).cast<Dispute>().toList();

      _logger.d('Found ${disputes.length} disputes for user');
      return disputes;
    } catch (e) {
      _logger.e('Failed to fetch user disputes: $e');
      return [];
    }
  }

  /// Create a new dispute for an order
  Future<bool> createDispute(String orderId) async {
    try {
      _logger.d('Creating dispute for order: $orderId');

      // Get user's session for the order to get the trade key
      final sessions = _ref.read(sessionNotifierProvider);
      final session = sessions.cast<dynamic>().firstWhere(
        (s) => s.orderId == orderId,
        orElse: () => null,
      );
      
      if (session == null) {
        _logger.e('No session found for order: $orderId, cannot create dispute');
        return false;
      }
      
      final privateKey = session.tradeKey.private;
      if (privateKey.isEmpty) {
        _logger.e('Session trade key private key is empty for order: $orderId');
        return false;
      }

      // Create dispute message according to Mostro protocol
      final disputeMessage = [
        {
          'order': {
            'version': 1,
            'id': orderId,
            'action': 'dispute',
            'payload': null,
          }
        },
        null // Signature placeholder
      ];

      // Create and sign the Nostr event using NostrUtils
      final signedEvent = NostrUtils.createEvent(
        kind: 4, // Direct message kind
        content: jsonEncode(disputeMessage),
        privateKey: privateKey,
        tags: [
          ['p', _mostroPubkey], // Send to Mostro
        ],
      );
      
      // Send the event to Mostro
      await _nostrService.publishEvent(signedEvent);
      
      _logger.d('Successfully sent dispute creation for order: $orderId');
      return true;
    } catch (e) {
      _logger.e('Failed to create dispute: $e');
      return false;
    }
  }

  /// Get dispute details by dispute ID
  Future<Dispute?> getDisputeDetails(String disputeId) async {
    try {
      _logger.d('Fetching dispute details for: $disputeId');

      // Create filter for specific dispute
      final filter = NostrFilter(
        kinds: [38383], // Dispute event kind
        authors: [_mostroPubkey],
      );

      final events = await _nostrService.fetchEvents(filter);
      
      if (events.isEmpty) {
        _logger.w('No dispute found with ID: $disputeId');
        return null;
      }

      // Filter events by dispute ID and get the latest event
      final disputeEvents = events.where((event) {
        final dTag = event.tags?.firstWhere(
          (tag) => tag.isNotEmpty && tag[0] == 'd' && tag.length > 1 && tag[1] == disputeId,
          orElse: () => [],
        );
        return dTag != null && dTag.isNotEmpty;
      }).toList();

      if (disputeEvents.isEmpty) {
        _logger.w('No dispute found with ID: $disputeId');
        return null;
      }

      // Find the latest event for this dispute
      final latestEvent = events.reduce((a, b) {
        final aTime = a.createdAt as int? ?? 0;
        final bTime = b.createdAt as int? ?? 0;
        return aTime > bTime ? a : b;
      });

      final disputeEvent = DisputeEvent.fromEvent(latestEvent);
      
      // Convert DisputeEvent to Dispute model
      // Note: We may need additional data from Mostro messages
      return Dispute(
        disputeId: disputeEvent.disputeId,
        status: disputeEvent.status,
        // orderId and other fields would come from additional queries
      );
    } catch (e) {
      _logger.e('Failed to get dispute details: $e');
      return null;
    }
  }

  /// Subscribe to dispute events for real-time updates
  Stream<Dispute> subscribeToDisputeEvents() {
    try {
      _logger.d('Subscribing to dispute events');

      // Create filter for dispute events from Mostro
      final filter = NostrFilter(
        kinds: [38383], // Dispute event kind
        authors: [_mostroPubkey],
        since: DateTime.now(),
        additionalFilters: {
          '#z': ['dispute'], // Filter for dispute events
        },
      );

      final request = NostrRequest(
        filters: [filter],
        subscriptionId: 'dispute-events-${DateTime.now().millisecondsSinceEpoch}',
      );

      // Subscribe to events and transform to Dispute stream
      return _nostrService.subscribeToEvents(request)
          .map((event) {
            try {
              final content = jsonDecode(event.content ?? '{}');
              return Dispute.fromNostrEvent(event, content);
            } catch (e) {
              _logger.w('Failed to parse dispute event ${event.id}: $e');
              throw e;
            }
          })
          .handleError((error) {
            _logger.e('Error in dispute events stream: $error');
          });
    } catch (e) {
      _logger.e('Failed to subscribe to dispute events: $e');
      return const Stream.empty();
    }
  }
}

// Providers moved to features/disputes/providers/dispute_providers.dart
