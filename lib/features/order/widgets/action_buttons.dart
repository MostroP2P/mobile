import 'package:flutter/material.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as nostr_action;
import 'package:mostro_mobile/shared/widgets/mostro_reactive_button.dart';

class ActionButtons extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onSubmit;
  final int? currentRequestId;

  const ActionButtons({
    super.key,
    required this.onCancel,
    required this.onSubmit,
    required this.currentRequestId,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: onCancel,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E2230),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 48,
            child: MostroReactiveButton(
              label: 'Submit',
              buttonStyle: ButtonStyleType.raised,
              orderId: currentRequestId?.toString() ?? '',
              action: nostr_action.Action.newOrder,
              onPressed: onSubmit,
              timeout: const Duration(seconds: 5),
              showSuccessIndicator: true,
              backgroundColor: const Color(0xFF7856AF),
            ),
          ),
        ),
      ],
    );
  }
}
