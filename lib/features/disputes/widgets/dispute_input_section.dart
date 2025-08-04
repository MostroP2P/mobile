import 'package:flutter/material.dart';
import 'package:mostro_mobile/features/chat/widgets/message_input.dart';

class DisputeInputSection extends StatelessWidget {
  final String orderId;
  final String? selectedInfoType;
  final ValueChanged<String?> onInfoTypeChanged;

  const DisputeInputSection({
    super.key,
    required this.orderId,
    required this.selectedInfoType,
    required this.onInfoTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1.0,
          ),
        ),
      ),
      child: MessageInput(
        orderId: orderId,
        selectedInfoType: selectedInfoType,
        onInfoTypeChanged: onInfoTypeChanged,
      ),
    );
  }
}
