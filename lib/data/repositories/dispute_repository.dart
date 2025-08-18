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
      
      // Log detailed session information
      for (final session in sessions) {
        _logger.d('Session: orderId=${session.orderId}, tradeKey=${session.tradeKey.public}');
      }

      // Try multiple approaches: encrypted DMs (kind 1059), regular DMs (kind 4), and dispute events (kind 38383)
      // Encrypted direct messages to user (from any author, not just Mostro)
      final encryptedDmFilter = NostrFilter(
        kinds: [1059], // Encrypted direct message kind
        since: DateTime.now().subtract(const Duration(days: 90)),
        additionalFilters: {
          '#p': userPubkeys, // Messages sent to user's pubkeys
        },
      );
      
      // Regular direct messages from Mostro
      final dmFilter = NostrFilter(
        kinds: [4], // Direct message kind
        authors: [_mostroPubkey],
        since: DateTime.now().subtract(const Duration(days: 90)),
        additionalFilters: {
          '#p': userPubkeys, // Messages sent to user's pubkeys
        },
      );
      
      // Also try dispute events (original approach)
      final disputeFilter = NostrFilter(
        kinds: [38383], // Dispute event kind
        authors: [_mostroPubkey],
        since: DateTime.now().subtract(const Duration(days: 90)),
        additionalFilters: {
          '#z': ['dispute'], // Filter for dispute events
        },
      );

      // Fetch all types of events
      final encryptedDmEvents = await _nostrService.fetchEvents(encryptedDmFilter);
      final dmEvents = await _nostrService.fetchEvents(dmFilter);
      final disputeEvents = await _nostrService.fetchEvents(disputeFilter);
      final events = [...encryptedDmEvents, ...dmEvents, ...disputeEvents];
      
      _logger.d('Fetched ${encryptedDmEvents.length} encrypted DMs, ${dmEvents.length} regular DMs, and ${disputeEvents.length} dispute events from Mostro (total: ${events.length})');

      // Log each event for debugging
      for (final event in events) {
        _logger.d('=== DISPUTE EVENT ${event.id} ===');
        _logger.d('Content: ${event.content}');
        _logger.d('Tags: ${event.tags}');
        
        // Try to parse content and extract dispute info
        try {
          if (event.content != null && event.content!.isNotEmpty) {
            // Handle encrypted messages (kind 1059)
            if (event.kind == 1059) {
              _logger.d('Found encrypted message (kind 1059), attempting to decrypt...');
              
              // Try to decrypt with each session's private key
              for (final session in sessions) {
                try {
                  final decryptedEvent = await NostrUtils.decryptNIP59Event(event, session.tradeKey.private);
                  _logger.d('Successfully decrypted message with session ${session.orderId}');
                  _logger.d('Decrypted content: ${decryptedEvent.content}');
                  
                  // Parse the decrypted content
                  final content = jsonDecode(decryptedEvent.content!);
                  if (content is List && content.isNotEmpty) {
                    final orderData = content[0];
                    if (orderData is Map<String, dynamic>) {
                      final order = orderData['order'] as Map<String, dynamic>?;
                      final orderId = order?['id'] as String?;
                      final action = order?['action'] as String?;
                      final payload = order?['payload'] as Map<String, dynamic>?;
                      final disputeId = payload?['dispute'] as String?;
                      _logger.d('Extracted from decrypted - orderId: $orderId, action: $action, disputeId: $disputeId');
                    }
                  }
                  break; // Successfully decrypted, stop trying other keys
                } catch (e) {
                  _logger.d('Failed to decrypt with session ${session.orderId}: $e');
                  continue; // Try next session key
                }
              }
            } else {
              // Handle unencrypted messages
              final content = jsonDecode(event.content!);
              if (content is List && content.isNotEmpty) {
                final orderData = content[0];
                if (orderData is Map<String, dynamic>) {
                  final order = orderData['order'] as Map<String, dynamic>?;
                  final orderId = order?['id'] as String?;
                  final action = order?['action'] as String?;
                  final payload = order?['payload'] as Map<String, dynamic>?;
                  final disputeId = payload?['dispute'] as String?;
                  _logger.d('Extracted - orderId: $orderId, action: $action, disputeId: $disputeId');
                }
              }
            }
          }
        } catch (e) {
          _logger.d('Failed to parse event content: $e');
        }
        _logger.d('=== END EVENT ===');
      }

      _logger.d(
          'User sessions: ${sessions.map((s) => 'orderId=${s.orderId}, tradeKey=${s.tradeKey.public}').toList()}');

      // Simplified approach: Include all events and let the dispute creation logic handle filtering
      final List<NostrEvent> userEvents = events;
      
      _logger.d('Processing ${userEvents.length} events for dispute extraction');

      // Convert events to Dispute objects - simplified logic
      final List<Dispute> disputes = [];
      final userOrderIds = sessions.map((s) => s.orderId).where((id) => id != null).toSet();
      
      _logger.d('User order IDs: $userOrderIds');
      
      for (final event in userEvents) {
        try {
          String? extractedOrderId;
          String? extractedDisputeId;
          String? extractedStatus = 'initiated';
          String? extractedAction;
          
          // Handle encrypted messages (kind 1059)
          if (event.kind == 1059) {
            for (final session in sessions) {
              try {
                final decryptedEvent = await NostrUtils.decryptNIP59Event(event, session.tradeKey.private);
                final decryptedContent = jsonDecode(decryptedEvent.content!);
                
                if (decryptedContent is List && decryptedContent.isNotEmpty) {
                  final orderData = decryptedContent[0];
                  if (orderData is Map<String, dynamic>) {
                    final order = orderData['order'] as Map<String, dynamic>?;
                    if (order != null) {
                      extractedOrderId = order['id'] as String?;
                      extractedAction = order['action'] as String?;
                      final payload = order['payload'] as Map<String, dynamic>?;
                      extractedDisputeId = payload?['dispute'] as String?;
                      _logger.d('Extracted from encrypted event: orderId=$extractedOrderId, disputeId=$extractedDisputeId, action=$extractedAction');
                      break; // Successfully decrypted
                    }
                  }
                }
              } catch (e) {
                continue; // Try next session key
              }
            }
          }
          // Handle unencrypted messages
          else {
            final contentStr = event.content?.trim();
            if (contentStr != null && contentStr.isNotEmpty) {
              try {
                final content = jsonDecode(contentStr);
                
                // Handle direct message format: [{"order": {...}}, null]
                if (content is List && content.isNotEmpty) {
                  final orderData = content[0];
                  if (orderData is Map<String, dynamic>) {
                    final order = orderData['order'] as Map<String, dynamic>?;
                    if (order != null) {
                      extractedOrderId = order['id'] as String?;
                      extractedAction = order['action'] as String?;
                      final payload = order['payload'] as Map<String, dynamic>?;
                      extractedDisputeId = payload?['dispute'] as String?;
                      _logger.d('Extracted from unencrypted event: orderId=$extractedOrderId, disputeId=$extractedDisputeId, action=$extractedAction');
                    }
                  }
                }
                // Handle dispute event format (kind 38383)
                else if (content is Map<String, dynamic>) {
                  final dispute = Dispute.fromNostrEvent(event, content);
                  if (userOrderIds.contains(dispute.orderId)) {
                    _logger.d('Adding dispute from kind 38383: ${dispute.disputeId} for order ${dispute.orderId}');
                    disputes.add(dispute);
                  }
                  continue; // Skip to next event
                }
              } catch (e) {
                _logger.d('Failed to parse content: $e');
              }
            }
            
            // Handle empty content events (kind 38383) - fallback
            if (extractedOrderId == null && event.kind == 38383) {
              final dTag = event.tags?.firstWhere(
                (tag) => tag.isNotEmpty && tag[0] == 'd',
                orElse: () => [],
              );
              final sTag = event.tags?.firstWhere(
                (tag) => tag.isNotEmpty && tag[0] == 's',
                orElse: () => [],
              );
              
              if (dTag != null && dTag.length > 1) {
                extractedDisputeId = dTag[1];
                extractedStatus = sTag != null && sTag.length > 1 ? sTag[1] : 'unknown';
                
                // For empty content events, try to match with any user order
                if (userOrderIds.isNotEmpty) {
                  extractedOrderId = userOrderIds.first; // Use first available order as fallback
                  _logger.d('Fallback association for empty event: disputeId=$extractedDisputeId, orderId=$extractedOrderId');
                }
              }
            }
          }
          
          // Create dispute if we have both IDs and the order belongs to the user
          if (extractedOrderId != null && extractedDisputeId != null && userOrderIds.contains(extractedOrderId)) {
            _logger.d('Creating dispute: disputeId=$extractedDisputeId, orderId=$extractedOrderId, status=$extractedStatus, action=$extractedAction');
            disputes.add(Dispute(
              disputeId: extractedDisputeId,
              orderId: extractedOrderId,
              status: extractedStatus,
              createdAt: DateTime.now(),
              action: extractedAction,
            ));
          }
        } catch (e) {
          _logger.w('Failed to process event ${event.id}: $e');
        }
      }

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
        _logger
            .e('No session found for order: $orderId, cannot create dispute');
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
          (tag) =>
              tag.isNotEmpty &&
              tag[0] == 'd' &&
              tag.length > 1 &&
              tag[1] == disputeId,
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
        final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
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
        subscriptionId:
            'dispute-events-${DateTime.now().millisecondsSinceEpoch}',
      );

      // Subscribe to events and transform to Dispute stream
      return _nostrService.subscribeToEvents(request).map((event) {
        try {
          final content = jsonDecode(event.content ?? '{}');
          return Dispute.fromNostrEvent(event, content);
        } catch (e) {
          _logger.w('Failed to parse dispute event ${event.id}: $e');
          throw e;
        }
      }).handleError((error) {
        _logger.e('Error in dispute events stream: $error');
      });
    } catch (e) {
      _logger.e('Failed to subscribe to dispute events: $e');
      return const Stream.empty();
    }
  }
}

// Providers moved to features/disputes/providers/dispute_providers.dart
