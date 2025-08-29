import 'dart:async';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/data/models/dispute_event.dart';
import 'package:mostro_mobile/data/models/peer.dart';
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
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

  /// Fetch user disputes from decrypted messages stored by MostroService
  /// The MostroService already handles NIP-17 decryption and stores dispute messages
  Future<List<Dispute>> fetchUserDisputes() async {
    try {
      final sessions = _ref.read(sessionNotifierProvider);
      if (sessions.isEmpty) {
        return [];
      }

      final messageStorage = _ref.read(mostroStorageProvider);
      final allMessages = await messageStorage.getAllMessages();
      final Map<String, Dispute> disputeMap = {};

      // Look for dispute-related messages in stored decrypted messages
      for (final message in allMessages) {
        
        // Look for dispute-related actions
        if (message.action.toString().contains('dispute')) {
          final action = message.action.toString();
          final orderId = message.id;
          
          if (action == 'dispute-initiated-by-you' || action == 'dispute-initiated-by-peer') {
            // Extract dispute data from payload
            if (message.payload is Dispute) {
              final dispute = message.payload as Dispute;
              final status = await _getDisputeStatus(dispute.disputeId);
              
              disputeMap[dispute.disputeId] = dispute.copyWith(
                orderId: orderId,
                action: action,
                status: status ?? 'initiated',
              );
            }
          } else if (action == 'admin-took-dispute') {
            // Update existing disputes with admin info
            if (message.payload is Peer) {
              final peer = message.payload as Peer;
              
              // Find existing dispute for this order and update with admin info
              disputeMap.forEach((disputeId, dispute) {
                if (dispute.orderId == orderId) {
                  disputeMap[disputeId] = dispute.copyWith(
                    adminPubkey: peer.publicKey,
                    adminTookAt: DateTime.now(),
                    status: 'in-progress',
                  );
                }
              });
            }
          } else if (action == 'admin-settled') {
            // Update existing disputes when admin resolves them
            disputeMap.forEach((disputeId, dispute) {
              if (dispute.orderId == orderId) {
                disputeMap[disputeId] = dispute.copyWith(
                  status: 'resolved',
                );
              }
            });
          }
        }
      }

      final result = disputeMap.values.toList()
        ..sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
      
      return result;
    } catch (e) {
      _logger.e('Failed to fetch user disputes: $e');
      return [];
    }
  }

  /// Get current dispute status from kind 38383 public events
  Future<String?> _getDisputeStatus(String disputeId) async {
    try {
      final disputeFilter = NostrFilter(
        kinds: [38383],
        authors: [_mostroPubkey],
        additionalFilters: {
          '#d': [disputeId],
          '#z': ['dispute'],
        },
      );

      final events = await _nostrService.fetchEvents(disputeFilter);
      if (events.isEmpty) return null;

      // Get the latest event for this dispute
      final latestEvent = events.reduce((a, b) {
        final aTime = a.createdAt is DateTime 
          ? (a.createdAt as DateTime).millisecondsSinceEpoch 
          : (a.createdAt as int) * 1000;
        final bTime = b.createdAt is DateTime 
          ? (b.createdAt as DateTime).millisecondsSinceEpoch 
          : (b.createdAt as int) * 1000;
        return aTime > bTime ? a : b;
      });

      final disputeEvent = DisputeEvent.fromEvent(latestEvent);
      return disputeEvent.status;
    } catch (e) {
      return null;
    }
  }


  /// Create a new dispute for an order
  Future<bool> createDispute(String orderId) async {
    try {
      _logger.d('Creating dispute for order: $orderId');

      // Get user's session for the order to get the trade key
      final sessions = _ref.read(sessionNotifierProvider);
      final session = sessions.firstWhereOrNull(
            (s) => s.orderId == orderId,
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

      // Convert the dispute message to JSON string
      final messageJson = jsonEncode(disputeMessage);
      
      // Encrypt the message using NIP-44 encryption
      final encryptedContent = await NostrUtils.encryptNIP44(
        messageJson,
        privateKey,
        _mostroPubkey
      );

      // Create and sign the Nostr event using NostrUtils with encrypted content
      final signedEvent = NostrUtils.createEvent(
        kind: 4, // Direct message kind
        content: encryptedContent,
        privateKey: privateKey,
        tags: [
          ['p', _mostroPubkey], // Send to Mostro
        ],
      );

      // Send the encrypted event to Mostro
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
      // Create copies to avoid concurrent modification during iteration
      final sessionsCopy = List<dynamic>.from(sessions);
      final userPubkeys = sessionsCopy.map((s) => s.tradeKey.public).toList();
      final userOrderIds = sessionsCopy.map((s) => s.orderId).where((id) => id != null).toSet();
      
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
      // Create copies to avoid concurrent modification during iteration
      final dmEventsCopy = List<dynamic>.from(dmEvents);
      final encryptedDmEventsCopy = List<dynamic>.from(encryptedDmEvents);
      final allEvents = [...disputeEvents, ...dmEventsCopy, ...encryptedDmEventsCopy];

      if (allEvents.isEmpty) {
        _logger.w('No dispute found with ID: $disputeId');
        return null;
      }

      // Try to find orderId from DM events first
      String? foundOrderId;
      String? foundAction;
      String? foundToken;
      
      _logger.d('Searching for disputeId $disputeId in ${dmEventsCopy.length} DMs and ${encryptedDmEventsCopy.length} encrypted DMs');
      
      // Search regular DMs
      for (final event in dmEventsCopy) {
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
                    // Extract user token from dispute array [disputeId, userToken, peerToken]
                    if (disputeArray.length > 1 && disputeArray[1] != null) {
                      foundToken = disputeArray[1].toString();
                    }
                    _logger.d('✅ Found orderId from DM: $foundOrderId, action: $foundAction, token: $foundToken');
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
        for (final event in encryptedDmEventsCopy) {
          for (final session in sessionsCopy) {
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
      // Create a copy of the list to avoid concurrent modification
      final disputeEventsCopy = List<NostrEvent>.from(disputeEvents);
      final filteredDisputeEvents = disputeEventsCopy.where((event) {
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
        disputeToken: foundToken, // Include user token from DM
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
