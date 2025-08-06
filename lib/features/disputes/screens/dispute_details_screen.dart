import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/features/disputes/providers/dispute_providers.dart';
import 'package:mostro_mobile/features/disputes/widgets/disputes_list.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_info_card.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_communication_section.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_input_section.dart';
import 'package:mostro_mobile/shared/widgets/bottom_nav_bar.dart';

class DisputeDetailsScreen extends ConsumerStatefulWidget {
  final String disputeId;

  const DisputeDetailsScreen({
    super.key,
    required this.disputeId,
  });

  @override
  ConsumerState<DisputeDetailsScreen> createState() => _DisputeDetailsScreenState();
}

class _DisputeDetailsScreenState extends ConsumerState<DisputeDetailsScreen> {
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
        title: const Text(
          'Dispute Details',
          style: TextStyle(
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
                      // Convert Dispute to DisputeData for the info card
                      DisputeInfoCard(dispute: _disputeToDisputeData(dispute)),
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

  /// Convert Dispute model to DisputeData for UI compatibility
  DisputeData _disputeToDisputeData(Dispute dispute) {
    return DisputeData(
      disputeId: dispute.disputeId,
      orderId: dispute.orderId ?? dispute.disputeId,
      status: dispute.status ?? 'unknown',
      description: _getDescriptionForStatus(dispute.status ?? 'unknown'),
      counterparty: 'Unknown', // Would need order data to determine counterparty
      isCreator: true, // Assume user is creator for now
      createdAt: DateTime.now(), // Would need creation timestamp from dispute event
    );
  }

  /// Get description based on dispute status
  String _getDescriptionForStatus(String status) {
    switch (status.toLowerCase()) {
      case 'initiated':
        return 'You opened this dispute';
      case 'in-progress':
        return 'Dispute is being reviewed by an admin';
      case 'resolved':
        return 'Dispute has been resolved';
      case 'closed':
        return 'Dispute has been closed';
      default:
        return 'Dispute status: $status';
    }
  }
}
