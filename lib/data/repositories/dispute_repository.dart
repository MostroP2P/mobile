import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
<<<<<<< HEAD
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
=======
>>>>>>> 4dfe38ce (refactor: simplify dispute creation using MostroMessage wrapper and NIP-17 protocol)
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';

/// Repository for managing dispute creation
class DisputeRepository {
  final NostrService _nostrService;
  final String _mostroPubkey;
  final Ref _ref;
  final Logger _logger = Logger();

  DisputeRepository(this._nostrService, this._mostroPubkey, this._ref);

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

      // Create dispute message using Gift Wrap protocol (NIP-17)
      final disputeMessage = MostroMessage(
        action: Action.dispute,
        id: orderId,
      );

      // Wrap message using NIP-17 Gift Wrap protocol
      final event = await disputeMessage.wrap(
        tradeKey: session.tradeKey,
        recipientPubKey: _mostroPubkey,
      );

      // Send the wrapped event to Mostro
      await _nostrService.publishEvent(event);

      _logger.d('Successfully sent dispute creation for order: $orderId');
      return true;
    } catch (e) {
      _logger.e('Failed to create dispute: $e');
      return false;
    }
  }

  Future<List<Dispute>> getUserDisputes() async {
    // Mock implementation for UI testing
    await Future.delayed(const Duration(milliseconds: 500));
    
    return [
      Dispute(
        disputeId: 'dispute_001',
        orderId: 'order_001',
        status: 'initiated',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        action: 'dispute-initiated-by-you',
      ),
      Dispute(
        disputeId: 'dispute_002',
        orderId: 'order_002',
        status: 'in-progress',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        action: 'dispute-initiated-by-peer',
        adminPubkey: 'admin_123',
      ),
    ];
  }

  Future<Dispute?> getDispute(String disputeId) async {
    // Mock implementation
    await Future.delayed(const Duration(milliseconds: 300));
    
    return Dispute(
      disputeId: disputeId,
      orderId: 'order_${disputeId.substring(0, 8)}',
      status: 'initiated',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      action: 'dispute-initiated-by-you',
    );
  }

  Future<void> sendDisputeMessage(String disputeId, String message) async {
    // Mock implementation
    await Future.delayed(const Duration(milliseconds: 200));
  }
}