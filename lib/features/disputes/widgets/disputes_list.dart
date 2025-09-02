import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_list_item.dart';
import 'package:mostro_mobile/data/models/dispute.dart';

class DisputesList extends StatelessWidget {
  const DisputesList({super.key});

  @override
  Widget build(BuildContext context) {
    // Only show hardcoded mock disputes in debug mode
    final mockDisputes = kDebugMode ? [
      DisputeData(
        disputeId: 'dispute_001',
        orderId: 'order_abc123',
        status: 'initiated',
        descriptionKey: DisputeDescriptionKey.initiatedByUser,
        counterparty: 'user_456',
        isCreator: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        userRole: UserRole.buyer,
      ),
      DisputeData(
        disputeId: 'dispute_002', 
        orderId: 'order_def456',
        status: 'in-progress',
        descriptionKey: DisputeDescriptionKey.inProgress,
        counterparty: 'admin_789',
        isCreator: false,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        userRole: UserRole.seller,
      ),
      DisputeData(
        disputeId: 'dispute_003',
        orderId: 'order_ghi789',
        status: 'resolved',
        descriptionKey: DisputeDescriptionKey.resolved,
        counterparty: 'user_123',
        isCreator: null, // Unknown creator state for resolved dispute
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        userRole: UserRole.buyer,
      ),
    ] : <DisputeData>[];

    if (mockDisputes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.gavel,
              size: 64,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              kDebugMode ? 'No disputes available' : 'Disputes not available',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              kDebugMode 
                ? 'Disputes will appear here when created'
                : 'This feature is coming soon',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: mockDisputes.length,
      itemBuilder: (context, index) {
        final disputeData = mockDisputes[index];
        
        return DisputeListItem(
          dispute: disputeData,
          onTap: () {
            context.push('/dispute_details/${disputeData.disputeId}');
          },
        );
      },
    );
  }
}

// DisputeData view model moved to lib/data/models/dispute.dart
