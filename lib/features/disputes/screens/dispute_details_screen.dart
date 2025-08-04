import 'package:flutter/material.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/disputes/widgets/disputes_list.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_info_card.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_communication_section.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_input_section.dart';
import 'package:mostro_mobile/shared/widgets/bottom_nav_bar.dart';

class DisputeDetailsScreen extends StatefulWidget {
  final DisputeData dispute;

  const DisputeDetailsScreen({
    super.key,
    required this.dispute,
  });

  @override
  State<DisputeDetailsScreen> createState() => _DisputeDetailsScreenState();
}

class _DisputeDetailsScreenState extends State<DisputeDetailsScreen> {
  String? _selectedInfoType;

  @override
  Widget build(BuildContext context) {
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
            color: Colors.white.withValues(alpha: 0.05), // More subtle border
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  DisputeInfoCard(dispute: widget.dispute),
                  const SizedBox(height: 24),
                  const DisputeCommunicationSection(),
                ],
              ),
            ),
          ),
          // Chat input positioned right above bottom nav bar - same as chat screen
          DisputeInputSection(
            orderId: widget.dispute.orderId,
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
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }
}
