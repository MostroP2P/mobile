import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/repositories/dispute_repository.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_list_item.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class DisputesList extends ConsumerWidget {
  const DisputesList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userDisputesAsync = ref.watch(userDisputesProvider);

    return userDisputesAsync.when(
      data: (disputes) {
        if (disputes.isEmpty) {
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
                  S.of(context)?.noDisputesAvailable ?? 'No disputes available',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Disputes will appear here when you open them from your trades',
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
          itemCount: disputes.length,
          itemBuilder: (context, index) {
            final disputeEvent = disputes[index];
            final disputeData = DisputeData.fromDisputeEvent(disputeEvent);
            
            return DisputeListItem(
              dispute: disputeData,
              onTap: () {
                context.push('/dispute_details', extra: disputeData);
              },
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.red1,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load disputes',
              style: TextStyle(
                color: AppTheme.red1,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.invalidate(userDisputesProvider);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// Data class for dispute display - bridges DisputeEvent to UI
class DisputeData {
  final String disputeId;
  final String orderId;
  final String status;
  final String description;
  final String counterparty;
  final bool isCreator;
  final DateTime createdAt;

  DisputeData({
    required this.disputeId,
    required this.orderId,
    required this.status,
    required this.description,
    required this.counterparty,
    required this.isCreator,
    required this.createdAt,
  });

  /// Create DisputeData from DisputeEvent
  factory DisputeData.fromDisputeEvent(dynamic disputeEvent) {
    // For now, we'll create basic data from the dispute event
    // In a full implementation, this would combine data from multiple sources
    return DisputeData(
      disputeId: disputeEvent.disputeId,
      orderId: disputeEvent.disputeId, // Placeholder - would need order mapping
      status: disputeEvent.status,
      description: _getDescriptionForStatus(disputeEvent.status),
      counterparty: 'Unknown', // Would need to fetch from order data
      isCreator: true, // Assume user is creator for now
      createdAt: DateTime.fromMillisecondsSinceEpoch(disputeEvent.createdAt * 1000),
    );
  }

  static String _getDescriptionForStatus(String status) {
    switch (status.toLowerCase()) {
      case 'initiated':
        return 'You opened this dispute';
      case 'in-progress':
        return 'Dispute is being reviewed by an admin';
      case 'settled':
        return 'Dispute has been resolved';
      case 'seller-refunded':
        return 'Dispute resolved - seller refunded';
      default:
        return 'Dispute status: $status';
    }
  }
}
