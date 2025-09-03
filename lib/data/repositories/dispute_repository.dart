import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

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