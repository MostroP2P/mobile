import 'package:flutter/material.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as nostr_action;
import 'package:mostro_mobile/shared/widgets/mostro_reactive_button.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class ActionButtons extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback? onSubmit;
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
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: onCancel,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.backgroundCard,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: Text(S.of(context)!.cancel),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 48,
            child: MostroReactiveButton(
              key: const Key('submitOrderButton'),
              label: S.of(context)!.submit,
              buttonStyle: ButtonStyleType.raised,
              orderId: currentRequestId?.toString() ?? '',
              action: nostr_action.Action.newOrder,
              onPressed: onSubmit,
              timeout: const Duration(seconds: 5),
              showSuccessIndicator: onSubmit != null, // Only show success indicator when enabled
              backgroundColor: onSubmit != null ? AppTheme.purpleButton : AppTheme.backgroundInactive,
              foregroundColor: onSubmit != null ? Colors.white : AppTheme.textInactive,
            ),
          ),
        ),
      ],
    );
  }
}
