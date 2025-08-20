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
  String? _selectedInfoType;

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
            return const Center(
              child: Text(
                'Dispute not found',
                style: TextStyle(color: Colors.white),
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
                          // Debug logging for dispute data flow
                          print('🐛 DisputeChatScreen - Building DisputeInfoCard');
                          print('🐛 DisputeChatScreen - dispute.orderId: ${dispute.orderId}');
                          print('🐛 DisputeChatScreen - dispute.disputeId: ${dispute.disputeId}');
                          print('🐛 DisputeChatScreen - dispute.action: ${dispute.action}');
                          print('🐛 DisputeChatScreen - dispute.status: ${dispute.status}');
                          print('🐛 DisputeChatScreen - dispute.createdAt: ${dispute.createdAt}');
                          
                          // If orderId is missing or unknown, fetch enhanced dispute details
                          final needsEnhancedLookup = dispute.orderId == null || dispute.orderId == 'Unknown Order ID';
                          
                          if (needsEnhancedLookup) {
                            print('🐛 DisputeChatScreen - orderId is null/unknown, fetching enhanced dispute details!');
                            
                            final enhancedDisputeAsync = ref.watch(disputeDetailsProvider(dispute.disputeId));
                            
                            return enhancedDisputeAsync.when(
                              loading: () {
                                print('🐛 DisputeChatScreen - Loading enhanced dispute details...');
                                return const Center(child: CircularProgressIndicator());
                              },
                              error: (error, stack) {
                                print('🐛 DisputeChatScreen - Error fetching enhanced dispute details: $error');
                                // Fallback to original dispute data
                                final disputeData = DisputeData.fromDispute(dispute);
                                return DisputeInfoCard(dispute: disputeData);
                              },
                              data: (enhancedDispute) {
                                print('🐛 DisputeChatScreen - Enhanced dispute loaded: ${enhancedDispute?.orderId}');
                                
                                final finalDispute = enhancedDispute ?? dispute;
                                final orderState = finalDispute.orderId != null && finalDispute.orderId != 'Unknown Order ID'
                                  ? ref.watch(orderNotifierProvider(finalDispute.orderId!))
                                  : null;
                                
                                print('🐛 DisputeChatScreen - Using enhanced dispute orderId: ${finalDispute.orderId}');
                                print('🐛 DisputeChatScreen - orderState: $orderState');
                                print('🐛 DisputeChatScreen - orderState?.order?.id: ${orderState?.order?.id}');
                                
                                final disputeData = DisputeData.fromDispute(finalDispute, orderState: orderState);
                                
                                print('🐛 DisputeChatScreen - Final disputeData.orderId: ${disputeData.orderId}');
                                print('🐛 DisputeChatScreen - Final disputeData.status: ${disputeData.status}');
                                
                                return DisputeInfoCard(dispute: disputeData);
                              },
                            );
                          } else {
                            // Use original dispute data if orderId is available
                            print('🐛 DisputeChatScreen - Using original dispute orderId: ${dispute.orderId}');
                            
                            final orderState = ref.watch(orderNotifierProvider(dispute.orderId!));
                            
                            print('🐛 DisputeChatScreen - orderState: $orderState');
                            print('🐛 DisputeChatScreen - orderState.order.id: ${orderState.order?.id}');
                            print('🐛 DisputeChatScreen - orderState.order.kind: ${orderState.order?.kind}');
                            
                            final disputeData = DisputeData.fromDispute(dispute, orderState: orderState);
                            
                            print('🐛 DisputeChatScreen - Final disputeData.orderId: ${disputeData.orderId}');
                            print('🐛 DisputeChatScreen - Final disputeData.disputeId: ${disputeData.disputeId}');
                            print('🐛 DisputeChatScreen - Final disputeData.status: ${disputeData.status}');
                            
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
                selectedInfoType: _selectedInfoType,
                onInfoTypeChanged: (type) {
                  if (type != null) {
                    FocusScope.of(context).unfocus();
                  }
                  setState(() {
                    _selectedInfoType = type;
                  });
                },
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
                'Error loading dispute: $error',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(disputeDetailsProvider(widget.disputeId));
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }

}
