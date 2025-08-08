import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_list_item.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class DisputesList extends ConsumerWidget {
  const DisputesList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // For now, we'll use hardcoded dispute data
    final hardcodedDisputes = _getHardcodedDisputes();

    if (hardcodedDisputes.isEmpty) {
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
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: hardcodedDisputes.length,
      itemBuilder: (context, index) {
        final dispute = hardcodedDisputes[index];
        return DisputeListItem(
          dispute: dispute,
          onTap: () {
            context.push('/dispute_details', extra: dispute);
          },
        );
      },
    );
  }

  List<DisputeData> _getHardcodedDisputes() {
    return [
      DisputeData(
        disputeId: 'd38c43d6-3c57-4ff5-89fd-8c4078a3fe0e',
        orderId: 'd38c43d6-3c57-4ff5-89fd-8c4078a3fe0e',
        status: 'in-progress',
        description: 'You opened this dispute. You were selling sats.',
        counterparty: 'Fiery-Honeybadger',
        isCreator: true,
      ),
      DisputeData(
        disputeId: 'be54a0c0-ab1a-4478-ad29-d8917ce376a8',
        orderId: 'be54a0c0-ab1a-4478-ad29-d8917ce376a8',
        status: 'in-progress',
        description: 'This dispute was opened against you. You were buying sats.',
        counterparty: 'Lightning-Trader',
        isCreator: false,
      ),
    ];
  }
}

// Temporary data class for hardcoded disputes
class DisputeData {
  final String disputeId;
  final String orderId;
  final String status;
  final String description;
  final String counterparty;
  final bool isCreator;

  DisputeData({
    required this.disputeId,
    required this.orderId,
    required this.status,
    required this.description,
    required this.counterparty,
    required this.isCreator,
  });
}
