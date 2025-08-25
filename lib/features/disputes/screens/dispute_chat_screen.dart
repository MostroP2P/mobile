import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_info_card.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_communication_section.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_input_section.dart';
import 'package:mostro_mobile/features/disputes/providers/dispute_providers.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/shared/widgets/bottom_nav_bar.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class DisputeChatScreen extends ConsumerStatefulWidget {
  final String disputeId;

  const DisputeChatScreen({
    super.key,
    required this.disputeId,
  });

  @override
  ConsumerState<DisputeChatScreen> createState() => _DisputeChatScreenState();
}

class _DisputeChatScreenState extends ConsumerState<DisputeChatScreen> {

  @override
  Widget build(BuildContext context) {
    final disputeDetailsAsync = ref.watch(disputeDetailsProvider(widget.disputeId));

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          S.of(context)?.disputeDetails ?? 'Dispute Details',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            height: 1.0,
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
      ),
      body: disputeDetailsAsync.when(
        data: (dispute) {
          if (dispute == null) {
            return Center(
              child: Text(
                S.of(context)!.disputeNotFound,
                style: const TextStyle(color: Colors.white),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Builder(
                        builder: (context) {
                          // If orderId is missing or unknown, fetch enhanced dispute details
                          final needsEnhancedLookup = dispute.orderId == null || dispute.orderId == 'Unknown Order ID';
                          
                          if (needsEnhancedLookup) {
                            final enhancedDisputeAsync = ref.watch(disputeDetailsProvider(dispute.disputeId));
                            
                            return enhancedDisputeAsync.when(
                              loading: () => const Center(child: CircularProgressIndicator()),
                              error: (error, stack) {
                                // Fallback to original dispute data
                                final disputeData = DisputeData.fromDispute(dispute);
                                return DisputeInfoCard(dispute: disputeData);
                              },
                              data: (enhancedDispute) {
                                
                                final finalDispute = enhancedDispute ?? dispute;
                                final orderState = finalDispute.orderId != null && finalDispute.orderId != 'Unknown Order ID'
                                  ? ref.watch(orderNotifierProvider(finalDispute.orderId!))
                                  : null;
                                
                                
                                final disputeData = DisputeData.fromDispute(finalDispute, orderState: orderState);
                                
                                
                                return DisputeInfoCard(dispute: disputeData);
                              },
                            );
                          } else {
                            // Use original dispute data if orderId is available
                            
                            final orderState = ref.watch(orderNotifierProvider(dispute.orderId!));
                            
                            
                            final disputeData = DisputeData.fromDispute(dispute, orderState: orderState);
                            
                            
                            return DisputeInfoCard(dispute: disputeData);
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                      DisputeCommunicationSection(disputeId: widget.disputeId),
                    ],
                  ),
                ),
              ),
              // Chat input positioned right above bottom nav bar
              DisputeInputSection(
                disputeId: widget.disputeId,
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                S.of(context)!.errorLoadingDispute(error.toString()),
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(disputeDetailsProvider(widget.disputeId));
                },
                child: Text(S.of(context)!.retry),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }

}
