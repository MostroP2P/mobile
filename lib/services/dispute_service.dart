import 'dart:math';
import 'package:mostro_mobile/data/models/dispute.dart';

/// Stub service for disputes - UI only implementation
class DisputeService {
  static final DisputeService _instance = DisputeService._internal();
  factory DisputeService() => _instance;
  DisputeService._internal();

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
    
    // Safe prefix extraction to avoid RangeError
    final prefixLen = min(8, disputeId.length);
    final orderIdSuffix = disputeId.isEmpty ? 'unknown' : disputeId.substring(0, prefixLen);
    
    return Dispute(
      disputeId: disputeId,
      orderId: 'order_$orderIdSuffix',
      status: 'initiated',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      action: 'dispute-initiated-by-you',
    );
  }

  Future<void> sendDisputeMessage(String disputeId, String message) async {
    // Mock implementation
    await Future.delayed(const Duration(milliseconds: 200));
  }

  Future<void> initiateDispute(String orderId, String reason) async {
    // Mock implementation
    await Future.delayed(const Duration(milliseconds: 500));
  }
}