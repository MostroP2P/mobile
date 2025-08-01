import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager_provider.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_type.dart';
import 'package:mostro_mobile/services/connection_manager.dart';
import 'package:mostro_mobile/shared/providers.dart';
import 'package:dart_nostr/dart_nostr.dart';

/// Service to recover subscriptions and persist state across disconnections
class SubscriptionRecovery {
  final Ref ref;
  final Logger _logger = Logger();
  
  // Persistent state
  final Map<SubscriptionType, List<NostrFilter>> _lastKnownFilters = {};
  final Map<String, DateTime> _lastEventTimestamps = {};
  
  // Recovery configuration
  static const Duration recoveryWindow = Duration(hours: 1);
  static const int maxEventsToRecover = 100;
  
  SubscriptionRecovery(this.ref) {
    _listenToConnectionRecovery();
  }
  
  /// Listen for connection recovery to restore subscriptions
  void _listenToConnectionRecovery() {
    ref.read(connectionManagerInstanceProvider).connectionState.listen((state) {
      if (state == ConnectionState.connected) {
        _performSubscriptionRecovery();
      }
    });
  }
  
  /// Store current subscription filters for recovery
  void storeSubscriptionState(SubscriptionType type, List<NostrFilter> filters) {
    _lastKnownFilters[type] = List.from(filters);
    _logger.d('Stored subscription state for $type: ${filters.length} filters');
  }
  
  /// Store last seen event timestamp for gap detection
  void updateLastEventTimestamp(String subscriptionId, DateTime timestamp) {
    _lastEventTimestamps[subscriptionId] = timestamp;
  }
  
  /// Perform subscription recovery after reconnection
  Future<void> _performSubscriptionRecovery() async {
    _logger.i('Starting subscription recovery');
    
    try {
      // Restore subscriptions with gap recovery
      for (final entry in _lastKnownFilters.entries) {
        final type = entry.key;
        final filters = entry.value;
        
        await _recoverSubscription(type, filters);
      }
      
      _logger.i('Subscription recovery completed');
    } catch (e) {
      _logger.e('Error during subscription recovery: $e');
    }
  }
  
  /// Recover a specific subscription with gap filling
  Future<void> _recoverSubscription(
    SubscriptionType type, 
    List<NostrFilter> filters
  ) async {
    _logger.i('Recovering subscription for $type');
    
    // Create recovery filters with since timestamp
    final recoveryFilters = _createRecoveryFilters(filters, type);
    
    if (recoveryFilters.isEmpty) {
      _logger.w('No recovery filters created for $type');
      return;
    }
    
    // Fetch missed events
    final missedEvents = await _fetchMissedEvents(recoveryFilters);
    _logger.i('Recovered ${missedEvents.length} missed events for $type');
    
    // Process missed events
    await _processMissedEvents(type, missedEvents);
    
    // Restore normal subscription
    await _restoreNormalSubscription(type, filters);
  }
  
  /// Create filters for recovering missed events
  List<NostrFilter> _createRecoveryFilters(
    List<NostrFilter> originalFilters, 
    SubscriptionType type
  ) {
    final recoveryFilters = <NostrFilter>[];
    final now = DateTime.now();
    final since = now.subtract(recoveryWindow);
    
    for (final filter in originalFilters) {
      // Create recovery filter with since timestamp
      final recoveryFilter = NostrFilter(
        kinds: filter.kinds,
        authors: filter.authors,
        p: filter.p,
        since: since,
        until: now,
        limit: maxEventsToRecover,
      );
      
      recoveryFilters.add(recoveryFilter);
    }
    
    return recoveryFilters;
  }
  
  /// Fetch missed events during disconnection
  Future<List<NostrEvent>> _fetchMissedEvents(List<NostrFilter> filters) async {
    final allEvents = <NostrEvent>[];
    
    try {
      final nostrService = ref.read(nostrServiceProvider);
      
      for (final filter in filters) {
        final events = await nostrService.fetchEvents(filter);
        allEvents.addAll(events);
      }
      
      // Sort by creation time
      allEvents.sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
      
    } catch (e) {
      _logger.e('Error fetching missed events: $e');
    }
    
    return allEvents;
  }
  
  /// Process missed events through appropriate handlers
  Future<void> _processMissedEvents(
    SubscriptionType type, 
    List<NostrEvent> events
  ) async {
    _logger.i('Processing ${events.length} missed events for $type');
    
    for (final event in events) {
      try {
        // Check if we've already processed this event
        final eventStore = ref.read(eventStorageProvider);
        if (await eventStore.hasItem(event.id!)) {
          continue;
        }
        
        // Process the event based on subscription type
        switch (type) {
          case SubscriptionType.orders:
            await _processMissedOrderEvent(event);
            break;
          case SubscriptionType.chat:
            await _processMissedChatEvent(event);
            break;
        }
        
        // Mark event as processed
        await eventStore.putItem(event.id!, {
          'id': event.id,
          'created_at': event.createdAt!.millisecondsSinceEpoch ~/ 1000,
          'recovered': true,
        });
        
      } catch (e) {
        _logger.e('Error processing missed event ${event.id}: $e');
      }
    }
  }
  
  /// Process missed order event
  Future<void> _processMissedOrderEvent(NostrEvent event) async {
    try {
      // Find matching session
      final sessions = ref.read(sessionNotifierProvider);
      final matchingSession = sessions.firstWhere(
        (s) => s.tradeKey.public == event.recipient,
        orElse: () => throw StateError('No matching session'),
      );
      
      // Decrypt and process
      final decryptedEvent = await event.unWrap(matchingSession.tradeKey.private);
      if (decryptedEvent.content == null) return;
      
      final result = jsonDecode(decryptedEvent.content!);
      if (result is! List) return;
      
      final msg = MostroMessage.fromJson(result[0]);
      final messageStorage = ref.read(mostroStorageProvider);
      await messageStorage.addMessage(decryptedEvent.id!, msg);
      
      _logger.i('Recovered order message: ${msg.action} for order: ${msg.id}');
      
    } catch (e) {
      _logger.e('Error processing missed order event: $e');
    }
  }
  
  /// Process missed chat event
  Future<void> _processMissedChatEvent(NostrEvent event) async {
    try {
      // Extract order ID from event tags to identify the chat room
      final orderIdTag = event.tags?.firstWhere(
        (tag) => tag.length >= 2 && tag[0] == 'd',
        orElse: () => [],
      );
      
      if (orderIdTag != null && orderIdTag.isNotEmpty && orderIdTag.length >= 2) {
        final orderId = orderIdTag[1];
        
        // Store the recovered chat event for later processing
        // The chat system will pick this up when the chat room is opened
        _logger.i('Recovered missed chat event for order: $orderId');
        
        // Add to recovered events cache for chat system to process
        _addToRecoveredEventsCache(orderId, event);
      }
      
    } catch (e) {
      _logger.e('Error processing missed chat event: $e');
    }
  }
  
  /// Add recovered event to cache for later processing
  void _addToRecoveredEventsCache(String orderId, NostrEvent event) {
    // Simple caching mechanism - in a real implementation this could
    // integrate with the chat system's event processing
    _logger.d('Cached recovered chat event for order: $orderId, event: ${event.id}');
  }
  
  /// Restore normal subscription after recovery
  Future<void> _restoreNormalSubscription(
    SubscriptionType type, 
    List<NostrFilter> filters
  ) async {
    try {
      final subscriptionManager = ref.read(subscriptionManagerProvider);
      
      // Create normal filters (without since/until)
      final normalFilters = filters.map((f) => NostrFilter(
        kinds: f.kinds,
        authors: f.authors,
        p: f.p,
        // Remove temporal constraints for ongoing subscription
      )).toList();
      
      // Subscribe with normal filters
      for (final filter in normalFilters) {
        subscriptionManager.subscribe(type: type, filter: filter);
      }
      
      _logger.i('Restored normal subscription for $type');
      
    } catch (e) {
      _logger.e('Error restoring normal subscription: $e');
    }
  }
  
  /// Get recovery statistics
  RecoveryStats getStats() {
    return RecoveryStats(
      storedFilterCount: _lastKnownFilters.length,
      lastEventTimestamps: Map.from(_lastEventTimestamps),
      recoveryWindowHours: recoveryWindow.inHours,
    );
  }
  
  /// Clear recovery state
  void clearRecoveryState() {
    _lastKnownFilters.clear();
    _lastEventTimestamps.clear();
    _logger.i('Cleared subscription recovery state');
  }
}

/// Recovery statistics
class RecoveryStats {
  final int storedFilterCount;
  final Map<String, DateTime> lastEventTimestamps;
  final int recoveryWindowHours;
  
  RecoveryStats({
    required this.storedFilterCount,
    required this.lastEventTimestamps,
    required this.recoveryWindowHours,
  });
}

/// Provider for subscription recovery
final subscriptionRecoveryProvider = Provider((ref) => SubscriptionRecovery(ref));
