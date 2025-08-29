import 'package:mostro_mobile/data/models/dispute_chat.dart';
import 'package:mostro_mobile/data/models/dispute.dart';

/// Mock data for disputes UI development and testing
/// This file can be easily removed when real dispute data is implemented
class DisputeMockData {
  
  /// Mock dispute list for the disputes screen
  static List<DisputeData> get mockDisputes => [
    DisputeData(
      disputeId: 'dispute_001',
      orderId: 'order_123',
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      status: 'initiated',
      descriptionKey: DisputeDescriptionKey.initiatedByUser,
      counterparty: null,
      isCreator: true,
      userRole: UserRole.buyer,
    ),
    DisputeData(
      disputeId: 'dispute_002', 
      orderId: 'order_456',
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      status: 'in-progress',
      descriptionKey: DisputeDescriptionKey.inProgress,
      counterparty: 'admin_123',
      isCreator: false,
      userRole: UserRole.seller,
    ),
    DisputeData(
      disputeId: 'dispute_003',
      orderId: 'order_789', 
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      status: 'resolved',
      descriptionKey: DisputeDescriptionKey.resolved,
      counterparty: 'admin_123',
      isCreator: true,
      userRole: UserRole.buyer,
    ),
  ];

  /// Mock dispute details based on dispute ID
  static DisputeData? getDisputeById(String disputeId) {
    try {
      return mockDisputes.firstWhere(
        (dispute) => dispute.disputeId == disputeId,
      );
    } catch (e) {
      return _getDefaultMockDispute(disputeId);
    }
  }

  /// Mock chat messages based on dispute status
  static List<DisputeChat> getMockMessages(String disputeId, String status) {
    // If dispute is in initiated state, show no messages (waiting for admin)
    if (status == 'initiated') {
      return [];
    }
    
    if (status == 'resolved') {
      return [
        DisputeChat(
          id: '1',
          message: 'Hello, I need help with this order. The seller hasn\'t responded to my messages.',
          timestamp: DateTime.now().subtract(const Duration(days: 3, hours: 2)),
          isFromUser: true,
        ),
        DisputeChat(
          id: '2',
          message: 'I understand your concern. Let me review the order details and contact the seller.',
          timestamp: DateTime.now().subtract(const Duration(days: 3, hours: 1, minutes: 45)),
          isFromUser: false,
          adminPubkey: 'admin_123',
        ),
        DisputeChat(
          id: '3',
          message: 'I\'ve contacted the seller and they confirmed they will complete the payment within 2 hours.',
          timestamp: DateTime.now().subtract(const Duration(days: 2, hours: 12)),
          isFromUser: false,
          adminPubkey: 'admin_123',
        ),
        DisputeChat(
          id: '4',
          message: 'Thank you for your help. I\'ll wait for the payment.',
          timestamp: DateTime.now().subtract(const Duration(days: 2, hours: 11, minutes: 30)),
          isFromUser: true,
        ),
      ];
    } else {
      // in-progress status
      return [
        DisputeChat(
          id: '1',
          message: 'Hello, I need help with this order. The seller hasn\'t responded to my messages.',
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          isFromUser: true,
        ),
        DisputeChat(
          id: '2',
          message: 'I understand your concern. Let me review the order details and contact the seller.',
          timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 45)),
          isFromUser: false,
          adminPubkey: 'admin_123',
        ),
        DisputeChat(
          id: '3',
          message: 'Thank you for your patience. I\'m working on resolving this issue.',
          timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
          isFromUser: false,
          adminPubkey: 'admin_123',
        ),
      ];
    }
  }

  /// Creates a default mock dispute for unknown IDs
  static DisputeData _getDefaultMockDispute(String disputeId) {
    return DisputeData(
      disputeId: disputeId,
      orderId: 'order_unknown',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      status: 'in-progress',
      descriptionKey: DisputeDescriptionKey.inProgress,
      counterparty: 'admin_123',
      isCreator: true,
      userRole: UserRole.buyer,
    );
  }

  /// Mock dispute creation - returns a new dispute ID
  static String createMockDispute({
    required String orderId,
    required String reason,
    required String initiatorRole,
    required Map<String, dynamic> orderDetails,
  }) {
    final newDisputeId = 'dispute_${DateTime.now().millisecondsSinceEpoch}';
    
    // In a real implementation, this would save to database
    // For now, we just return the ID
    return newDisputeId;
  }

  /// Check if mock data is enabled (can be used to toggle mock vs real data)
  static const bool isMockEnabled = true;
}