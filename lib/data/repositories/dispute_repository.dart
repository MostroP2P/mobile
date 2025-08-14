import 'dart:async';
import 'dart:convert';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/data/models/dispute_event.dart';
import 'package:mostro_mobile/data/repositories/auth_repository.dart';
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

/// Repository for managing dispute data and events
class DisputeRepository {
  final NostrService _nostrService;
  final String _mostroPubkey;
  final AuthRepository _authRepository;
  final Logger _logger = Logger();

  DisputeRepository(this._nostrService, this._mostroPubkey, this._authRepository);

  /// Get order IDs that belong to the current user
  Future<Set<String>> _getUserOrderIds(String userPubkey) async {
    try {
      // Create filter for orders from Mostro that might involve this user
      final filter = NostrFilter(
        kinds: [38383], // Order event kind
        authors: [_mostroPubkey],
        since: DateTime.now().subtract(const Duration(days: 90)),
        additionalFilters: {
          '#z': ['order'], // Filter for order events
        },
      );

      final events = await _nostrService.fetchEvents(filter);
      final userOrderIds = <String>{};

      // Check each order event to see if it involves the user
      for (final event in events) {
        try {
          // Extract order ID from 'd' tag
          final dTag = event.tags?.firstWhere(
            (tag) => tag.isNotEmpty && tag[0] == 'd',
            orElse: () => [],
          );
          
          if (dTag != null && dTag.length > 1) {
            final orderId = dTag[1];
            
            // Check if this order involves the user by looking for their pubkey in tags
            final userInvolved = event.tags?.any((tag) => 
              tag.length > 1 && tag[1] == userPubkey
            ) ?? false;
            
            if (userInvolved) {
              userOrderIds.add(orderId);
            }
          }
        } catch (e) {
          _logger.w('Failed to parse order event ${event.id}: $e');
        }
      }

      _logger.d('Found ${userOrderIds.length} orders for user');
      return userOrderIds;
    } catch (e) {
      _logger.e('Failed to get user order IDs: $e');
      return <String>{};
    }
  }

  /// Fetch dispute events from Nostr for the current user
  Future<List<DisputeEvent>> fetchUserDisputes() async {
    try {
      _logger.d('Fetching user disputes from Nostr');

      // Get current user's pubkey from private key
      final privateKey = await _authRepository.getPrivateKey();
      if (privateKey == null) {
        _logger.w('User private key not available, cannot fetch disputes');
        return [];
      }
      
      final userPubkey = NostrUtils.derivePublicKey(privateKey);
      _logger.d('Fetching disputes for user pubkey: $userPubkey');

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
      
      // Parse dispute events and get user's orders to filter relevant disputes
      final disputeEvents = <DisputeEvent>[];
      final userOrderIds = await _getUserOrderIds(userPubkey);
      
      for (final event in events) {
        try {
          final disputeEvent = DisputeEvent.fromEvent(event);
          
          // Check if this dispute is related to any of the user's orders
          // In Mostro, dispute ID often corresponds to order ID
          if (userOrderIds.contains(disputeEvent.disputeId)) {
            disputeEvents.add(disputeEvent);
            _logger.d('Found user dispute: ${disputeEvent.disputeId} with status: ${disputeEvent.status}');
          }
        } catch (e) {
          _logger.w('Failed to parse dispute event ${event.id}: $e');
        }
      }

      // Sort by creation time (newest first)
      disputeEvents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      _logger.d('Fetched ${disputeEvents.length} user disputes');
      return disputeEvents;
    } catch (e) {
      _logger.e('Failed to fetch user disputes: $e');
      return [];
    }
  }

  /// Create a new dispute for an order
  Future<bool> createDispute(String orderId) async {
    try {
      _logger.d('Creating dispute for order: $orderId');

      // Get user's private key for signing
      final privateKey = await _authRepository.getPrivateKey();
      if (privateKey == null) {
        _logger.e('User private key not available, cannot create dispute');
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
  Stream<DisputeEvent> subscribeToDisputeEvents() {
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

      // Subscribe to events and transform to DisputeEvent stream
      return _nostrService.subscribeToEvents(request)
          .map((event) {
            try {
              return DisputeEvent.fromEvent(event);
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
