import 'dart:async';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/data/models/dispute_event.dart';
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';

/// Repository for managing dispute data and events
class DisputeRepository {
  final NostrService _nostrService;
  final String _mostroPubkey;
  final Logger _logger = Logger();

  DisputeRepository(this._nostrService, this._mostroPubkey);

  /// Fetch dispute events from Nostr for the current user
  Future<List<DisputeEvent>> fetchUserDisputes() async {
    try {
      _logger.d('Fetching user disputes from Nostr');

      // Create filter for dispute events
      final filter = NostrFilter(
        kinds: [38383], // Dispute event kind
        authors: [_mostroPubkey],
        since: DateTime.now().subtract(const Duration(days: 30)), // Last 30 days
      );

      final events = await _nostrService.fetchEvents(filter);
      
      final disputes = events
          .map((event) {
            try {
              return DisputeEvent.fromEvent(event);
            } catch (e) {
              _logger.w('Failed to parse dispute event ${event.id}: $e');
              return null;
            }
          })
          .where((dispute) => dispute != null)
          .cast<DisputeEvent>()
          .toList();

      _logger.d('Fetched ${disputes.length} dispute events');
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

      // TODO: Implement dispute creation
      // This would send a dispute action to Mostro
      // For now, we'll return true as a placeholder
      
      _logger.d('Dispute creation not yet implemented');
      return false;
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

      // Get the latest event for this dispute
      final latestEvent = disputeEvents.reduce((a, b) {
        final aTime = a.createdAt ?? 0;
        final bTime = b.createdAt ?? 0;
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

      final filter = NostrFilter(
        kinds: [38383], // Dispute event kind
        authors: [_mostroPubkey],
        since: DateTime.now(),
      );

      // Note: This is a simplified implementation
      // In a full implementation, we would need to properly handle the subscription
      // For now, return an empty stream as a placeholder
      _logger.w('Dispute events subscription not fully implemented yet');
      return const Stream.empty();
    } catch (e) {
      _logger.e('Failed to subscribe to dispute events: $e');
      return const Stream.empty();
    }
  }
}

/// Provider for dispute repository
final disputeRepositoryProvider = Provider<DisputeRepository>((ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final settings = ref.watch(settingsProvider);
  return DisputeRepository(nostrService, settings.mostroPublicKey);
});

/// Provider for user disputes
final userDisputesProvider = FutureProvider<List<DisputeEvent>>((ref) async {
  final repository = ref.watch(disputeRepositoryProvider);
  return repository.fetchUserDisputes();
});

/// Provider for specific dispute details
final disputeDetailsProvider = FutureProvider.family<Dispute?, String>((ref, disputeId) async {
  final repository = ref.watch(disputeRepositoryProvider);
  return repository.getDisputeDetails(disputeId);
});

/// Provider for dispute events stream
final disputeEventsStreamProvider = StreamProvider<DisputeEvent>((ref) {
  final repository = ref.watch(disputeRepositoryProvider);
  return repository.subscribeToDisputeEvents();
});
