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

  /// Debug method to check dispute fetching status
  Future<void> debugDisputeFetching() async {
    _logger.d('🔍 DEBUGGING DISPUTE FETCHING');
    
    // Check sessions
    final sessions = _ref.read(sessionNotifierProvider);
    _logger.d('Sessions count: ${sessions.length}');
    for (final session in sessions) {
      _logger.d('  Session: orderId=${session.orderId}, tradeKey=${session.tradeKey.public}');
    }
    
    // Check Mostro pubkey
    _logger.d('Mostro pubkey: $_mostroPubkey');
    
    // Try a simple dispute event fetch
    final simpleFilter = NostrFilter(
      kinds: [38383],
      authors: [_mostroPubkey],
      since: DateTime.now().subtract(const Duration(days: 30)),
    );
    
    final simpleEvents = await _nostrService.fetchEvents(simpleFilter);
    _logger.d('Simple dispute events found: ${simpleEvents.length}');
    
    for (final event in simpleEvents.take(3)) {
      _logger.d('Event ${event.id}: kind=${event.kind}, content=${event.content}, tags=${event.tags}');
    }
  }

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
      
      // Log if no events found at all
      if (events.isEmpty) {
        _logger.w('⚠️ NO EVENTS FOUND! This could mean:');
        _logger.w('  - No disputes exist for this user');
        _logger.w('  - Nostr connection issues');
        _logger.w('  - Wrong Mostro pubkey: $_mostroPubkey');
        _logger.w('  - User pubkeys not matching: $userPubkeys');
        return [];
      }

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

      // Convert events to Dispute objects - keep latest per disputeId to avoid duplicates
      final Map<String, Dispute> latestByDisputeId = {};
      final Map<String, DateTime> timeByDisputeId = {};
      final userOrderIds = sessions.map((s) => s.orderId).where((id) => id != null).toSet();
      
      _logger.d('User order IDs: $userOrderIds');
      _logger.d('Processing ${userEvents.length} events for disputes');
      
      for (final event in userEvents) {
        try {
          // Try to parse as DisputeEvent first (kind 38383)
          if (event.kind == 38383) {
            try {
              final disputeEvent = DisputeEvent.fromEvent(event);
              final eventTime = DateTime.fromMillisecondsSinceEpoch(disputeEvent.createdAt * 1000);
              
              _logger.d('Parsed DisputeEvent: disputeId=${disputeEvent.disputeId}, orderId=${disputeEvent.orderId}, status=${disputeEvent.status}');
              
              // Try to match orderId from sessions if not in event content
              String? finalOrderId = disputeEvent.orderId;
              String? disputeAction;
              
              // If no orderId in event content, try to match with user sessions
              if (finalOrderId == null && userOrderIds.isNotEmpty) {
                // For now, assume it's related to the user's order since they created the dispute
                finalOrderId = userOrderIds.first;
                disputeAction = 'dispute-initiated-by-you'; // User created this dispute
                _logger.d('Matched dispute ${disputeEvent.disputeId} to user order: $finalOrderId');
              } else if (finalOrderId != null && userOrderIds.contains(finalOrderId)) {
                disputeAction = 'dispute-initiated-by-you'; // User created this dispute
              }
              
              final existingTime = timeByDisputeId[disputeEvent.disputeId];
              if (existingTime == null || eventTime.isAfter(existingTime)) {
                latestByDisputeId[disputeEvent.disputeId] = Dispute(
                  disputeId: disputeEvent.disputeId,
                  orderId: finalOrderId,
                  status: disputeEvent.status,
                  createdAt: eventTime,
                  action: disputeAction,
                );
                timeByDisputeId[disputeEvent.disputeId] = eventTime;
                _logger.d('✅ Added dispute: ${disputeEvent.disputeId} with orderId: $finalOrderId, action: $disputeAction');
              }
              continue; // Skip to next event
            } catch (e) {
              _logger.d('Failed to parse as DisputeEvent: $e');
              // Fall through to legacy parsing
            }
          }
          
          // Legacy parsing for other event types
          String? extractedOrderId;
          String? extractedDisputeId;
          String? extractedStatus = 'initiated';
          String? extractedAction;
          // Determine event timestamp
          final dynamic createdAtRaw = event.createdAt;
          DateTime eventTime;
          if (createdAtRaw is DateTime) {
            eventTime = createdAtRaw;
          } else if (createdAtRaw is int) {
            // Assume seconds since epoch
            eventTime = DateTime.fromMillisecondsSinceEpoch(createdAtRaw * 1000);
          } else {
            eventTime = DateTime.now();
          }
          
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
                
                // Handle direct message format from Mostro: {"order": {...}}
                if (content is Map<String, dynamic>) {
                  final order = content['order'] as Map<String, dynamic>?;
                  if (order != null) {
                    extractedOrderId = order['id'] as String?;
                    extractedAction = order['action'] as String?;
                    final payload = order['payload'] as Map<String, dynamic>?;
                    if (payload != null && payload['dispute'] is List) {
                      final disputeArray = payload['dispute'] as List;
                      if (disputeArray.isNotEmpty) {
                        extractedDisputeId = disputeArray[0] as String?;
                      }
                    }
                    _logger.d('Extracted from Mostro DM: orderId=$extractedOrderId, disputeId=$extractedDisputeId, action=$extractedAction');
                  }
                }
                // Handle legacy format: [{"order": {...}}, null]
                else if (content is List && content.isNotEmpty) {
                  final orderData = content[0];
                  if (orderData is Map<String, dynamic>) {
                    final order = orderData['order'] as Map<String, dynamic>?;
                    if (order != null) {
                      extractedOrderId = order['id'] as String?;
                      extractedAction = order['action'] as String?;
                      final payload = order['payload'] as Map<String, dynamic>?;
                      extractedDisputeId = payload?['dispute'] as String?;
                      _logger.d('Extracted from legacy format: orderId=$extractedOrderId, disputeId=$extractedDisputeId, action=$extractedAction');
                    }
                  }
                }
                // Handle dispute event format (kind 38383)
                else if (content is Map<String, dynamic>) {
                  // For kind 38383 with JSON content, parse using DisputeEvent to reliably get tags
                  try {
                    final de = DisputeEvent.fromEvent(event);
                    if (de.orderId != null && userOrderIds.contains(de.orderId)) {
                      final dId = de.disputeId;
                      final eTime = eventTime;
                      final existingTime = timeByDisputeId[dId];
                      if (existingTime == null || eTime.isAfter(existingTime)) {
                        latestByDisputeId[dId] = Dispute(
                          disputeId: dId,
                          orderId: de.orderId,
                          status: de.status,
                          createdAt: DateTime.fromMillisecondsSinceEpoch(de.createdAt * 1000),
                          action: extractedAction,
                        );
                        timeByDisputeId[dId] = eTime;
                      }
                      _logger.d('Upserted dispute from kind 38383: $dId for order ${de.orderId}');
                    }
                  } catch (e) {
                    _logger.d('Failed to parse dispute event from kind 38383: $e');
                  }
                  continue; // Skip to next event
                }
              } catch (e) {
                _logger.d('Failed to parse content: $e');
              }
            }
            
            // Handle empty content events (kind 38383)
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
              }
            }
          }
          
          // Create/update dispute if we have dispute ID (relax order matching for now)
          if (extractedDisputeId != null) {
            _logger.d('Processing dispute: disputeId=$extractedDisputeId, orderId=$extractedOrderId, status=$extractedStatus, action=$extractedAction, time=$eventTime');
            _logger.d('User order IDs: $userOrderIds');
            _logger.d('Order match: ${extractedOrderId != null ? userOrderIds.contains(extractedOrderId) : "no orderId"}');
            
            // Accept dispute if we have disputeId, even without perfect order matching
            final existingTime = timeByDisputeId[extractedDisputeId];
            if (existingTime == null || eventTime.isAfter(existingTime)) {
              latestByDisputeId[extractedDisputeId] = Dispute(
                disputeId: extractedDisputeId,
                orderId: extractedOrderId, // May be null
                status: extractedStatus,
                createdAt: eventTime,
                action: extractedAction,
              );
              timeByDisputeId[extractedDisputeId] = eventTime;
              _logger.d('Upserted dispute: $extractedDisputeId');
            } else {
              _logger.d('Skipped older dispute event for: $extractedDisputeId');
            }
          } else {
            _logger.d('Skipping event without disputeId: orderId=$extractedOrderId');
          }
        } catch (e) {
          _logger.w('Failed to process event ${event.id}: $e');
        }
      }

      final result = latestByDisputeId.values.toList()
        ..sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
      _logger.d('Found ${result.length} disputes for user after de-duplication');
      return result;
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

      // Get user sessions to search for DMs
      final sessions = _ref.read(sessionNotifierProvider);
      final userPubkeys = sessions.map((s) => s.tradeKey.public).toList();
      final userOrderIds = sessions.map((s) => s.orderId).where((id) => id != null).toSet();
      
      _logger.d('User sessions: ${sessions.length}, orderIds: $userOrderIds, pubkeys: $userPubkeys');

      // Create filters for dispute events AND DMs that might contain dispute info
      final disputeEventFilter = NostrFilter(
        kinds: [38383], // Dispute event kind
        authors: [_mostroPubkey],
        additionalFilters: {
          '#d': [disputeId],
          '#z': ['dispute'],
        },
      );

      // Also search for DMs from Mostro that might contain dispute info
      final dmFilter = NostrFilter(
        kinds: [4], // Direct message kind
        authors: [_mostroPubkey],
        since: DateTime.now().subtract(const Duration(days: 90)),
        additionalFilters: {
          '#p': userPubkeys, // Messages sent to user's pubkeys
        },
      );

      // Search encrypted DMs as well
      final encryptedDmFilter = NostrFilter(
        kinds: [1059], // Encrypted direct message kind
        since: DateTime.now().subtract(const Duration(days: 90)),
        additionalFilters: {
          '#p': userPubkeys, // Messages sent to user's pubkeys
        },
      );

      final disputeEvents = await _nostrService.fetchEvents(disputeEventFilter);
      final dmEvents = await _nostrService.fetchEvents(dmFilter);
      final encryptedDmEvents = await _nostrService.fetchEvents(encryptedDmFilter);
      final allEvents = [...disputeEvents, ...dmEvents, ...encryptedDmEvents];

      if (allEvents.isEmpty) {
        _logger.w('No dispute found with ID: $disputeId');
        return null;
      }

      // Try to find orderId from DM events first
      String? foundOrderId;
      String? foundAction;
      
      _logger.d('Searching for disputeId $disputeId in ${dmEvents.length} DMs and ${encryptedDmEvents.length} encrypted DMs');
      
      // Search regular DMs
      for (final event in dmEvents) {
        try {
          if (event.content != null && event.content!.isNotEmpty) {
            final content = jsonDecode(event.content!);
            if (content is Map<String, dynamic>) {
              final order = content['order'] as Map<String, dynamic>?;
              if (order != null) {
                final payload = order['payload'] as Map<String, dynamic>?;
                if (payload != null && payload['dispute'] is List) {
                  final disputeArray = payload['dispute'] as List;
                  _logger.d('Checking DM event: disputeArray=$disputeArray, looking for $disputeId');
                  if (disputeArray.isNotEmpty && disputeArray[0] == disputeId) {
                    foundOrderId = order['id'] as String?;
                    foundAction = order['action'] as String?;
                    _logger.d('✅ Found orderId from DM: $foundOrderId, action: $foundAction');
                    break;
                  }
                } else if (payload != null && payload['dispute'] is String && payload['dispute'] == disputeId) {
                  // Handle case where dispute is a string instead of array
                  foundOrderId = order['id'] as String?;
                  foundAction = order['action'] as String?;
                  _logger.d('✅ Found orderId from DM (string format): $foundOrderId, action: $foundAction');
                  break;
                } else {
                  _logger.d('DM event payload structure: ${payload?.keys}');
                }
              }
            }
          }
        } catch (e) {
          _logger.d('Failed to parse DM event: $e');
        }
      }
      
      // Search encrypted DMs if not found in regular DMs
      if (foundOrderId == null) {
        _logger.d('Searching encrypted DMs for dispute $disputeId');
        for (final event in encryptedDmEvents) {
          for (final session in sessions) {
            try {
              final decryptedEvent = await NostrUtils.decryptNIP59Event(event, session.tradeKey.private);
              final content = jsonDecode(decryptedEvent.content!);
              
              if (content is List && content.isNotEmpty) {
                final orderData = content[0];
                if (orderData is Map<String, dynamic>) {
                  final order = orderData['order'] as Map<String, dynamic>?;
                  if (order != null) {
                    final payload = order['payload'] as Map<String, dynamic>?;
                    final payloadDisputeId = payload?['dispute'] as String?;
                    if (payloadDisputeId == disputeId) {
                      foundOrderId = order['id'] as String?;
                      foundAction = order['action'] as String?;
                      _logger.d('✅ Found orderId from encrypted DM: $foundOrderId, action: $foundAction');
                      break;
                    }
                  }
                }
              }
            } catch (e) {
              continue; // Try next session key
            }
          }
          if (foundOrderId != null) break;
        }
      }
      
      // If still no orderId found, try to match with user sessions based on timing or other heuristics
      if (foundOrderId == null && userOrderIds.isNotEmpty) {
        _logger.d('No orderId found in events, attempting session matching for dispute $disputeId');
        // For now, if user has only one active order, assume it's related to that order
        if (userOrderIds.length == 1) {
          foundOrderId = userOrderIds.first;
          foundAction = 'dispute-initiated-by-you';
          _logger.d('🔍 Matched dispute $disputeId to single user order: $foundOrderId');
        } else {
          _logger.w('Multiple user orders found, cannot determine which order dispute $disputeId belongs to');
        }
      }

      // Filter dispute events by dispute ID and get the latest event
      final filteredDisputeEvents = disputeEvents.where((event) {
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

      if (filteredDisputeEvents.isEmpty) {
        _logger.w('No dispute found with ID: $disputeId');
        return null;
      }

      // Find the latest event for this dispute among the filtered list
      final latestEvent = filteredDisputeEvents.reduce((a, b) {
        int aTime;
        if (a.createdAt is DateTime) {
          aTime = (a.createdAt as DateTime).millisecondsSinceEpoch;
        } else if (a.createdAt is int) {
          aTime = (a.createdAt as int) * 1000;
        } else {
          aTime = 0;
        }
        int bTime;
        if (b.createdAt is DateTime) {
          bTime = (b.createdAt as DateTime).millisecondsSinceEpoch;
        } else if (b.createdAt is int) {
          bTime = (b.createdAt as int) * 1000;
        } else {
          bTime = 0;
        }
        return aTime > bTime ? a : b;
      });

      final disputeEvent = DisputeEvent.fromEvent(latestEvent);

      // Convert DisputeEvent to Dispute model, using orderId from DM if found
      return Dispute(
        disputeId: disputeEvent.disputeId,
        status: disputeEvent.status,
        orderId: foundOrderId ?? disputeEvent.orderId, // Use orderId from DM if available
        createdAt: DateTime.fromMillisecondsSinceEpoch(disputeEvent.createdAt * 1000),
        action: foundAction, // Include action from DM
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
          final de = DisputeEvent.fromEvent(event);
          return Dispute(
            disputeId: de.disputeId,
            orderId: de.orderId,
            status: de.status,
            createdAt: DateTime.fromMillisecondsSinceEpoch(de.createdAt * 1000),
          );
        } catch (e) {
          _logger.w('Failed to parse DisputeEvent for ${event.id}: $e');
          // Fallback to legacy parser if available
          try {
            final content = jsonDecode(event.content ?? '{}');
            return Dispute.fromNostrEvent(event, content);
          } catch (e2) {
            _logger.w('Fallback parse also failed for ${event.id}: $e2');
            rethrow;
          }
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
