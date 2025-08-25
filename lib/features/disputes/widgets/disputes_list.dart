import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/disputes/providers/dispute_providers.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_list_item.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/data/models/dispute.dart';

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
                  S.of(context)!.disputesWillAppear,
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
            final dispute = disputes[index];
            
            // Get OrderState to determine who initiated the dispute
            final orderState = dispute.orderId != null 
              ? ref.watch(orderNotifierProvider(dispute.orderId!))
              : null;
            
            final disputeData = DisputeData.fromDispute(dispute, orderState: orderState);
            
            return DisputeListItem(
              dispute: disputeData,
              onTap: () {
                context.push('/dispute_details/${dispute.disputeId}');
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
              S.of(context)!.failedLoadDisputes,
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
              child: Text(S.of(context)!.retry),
            ),
          ],
        ),
      ),
    );
  }
}

// DisputeData view model moved to lib/data/models/dispute.dart
