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
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';

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

      // Validate trade key is present
      if (session.tradeKey.private.isEmpty) {
        _logger.e('Trade key is empty for order: $orderId, cannot create dispute');
        return false;
      }

      // Create dispute message using Gift Wrap protocol (NIP-59)
      final disputeMessage = MostroMessage(
        action: Action.dispute,
        id: orderId,
      );

      // Wrap message using Gift Wrap protocol (NIP-59)
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
    try {
      _logger.d('Getting user disputes from sessions');

      // Get all user sessions and check their order states for disputes
      final sessions = _ref.read(sessionNotifierProvider);
      final disputes = <Dispute>[];

      for (final session in sessions) {
        if (session.orderId != null) {
          try {
            // Get the order state for this session
            final orderState = _ref.read(orderNotifierProvider(session.orderId!));
            
            if (orderState.dispute != null) {
              disputes.add(orderState.dispute!);
            }
          } catch (e) {
            _logger.w('Failed to get order state for order ${session.orderId}: $e');
          }
        }
      }

      _logger.d('Found ${disputes.length} disputes from sessions');
      return disputes;
    } catch (e) {
      _logger.e('Failed to get user disputes: $e');
      return [];
    }
  }

  Future<Dispute?> getDispute(String disputeId) async {
    try {
      _logger.d('Getting dispute by ID: $disputeId');
      
      // Get all user disputes and find the one with matching ID
      final disputes = await getUserDisputes();
      final dispute = disputes.firstWhereOrNull(
        (d) => d.disputeId == disputeId,
      );
      
      if (dispute != null) {
        _logger.d('Found dispute with ID: $disputeId');
      } else {
        _logger.w('No dispute found with ID: $disputeId');
      }
      
      return dispute;
    } catch (e) {
      _logger.e('Failed to get dispute by ID $disputeId: $e');
      return null;
    }
  }

  Future<void> sendDisputeMessage(String disputeId, String message) async {
    // Mock implementation
    await Future.delayed(const Duration(milliseconds: 200));
  }
}