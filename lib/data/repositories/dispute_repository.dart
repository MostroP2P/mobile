import 'package:mostro_mobile/data/models/dispute.dart';

/// Stub repository for disputes - UI only implementation
class DisputeRepository {
  static final DisputeRepository _instance = DisputeRepository._internal();
  factory DisputeRepository() => _instance;
  DisputeRepository._internal();

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