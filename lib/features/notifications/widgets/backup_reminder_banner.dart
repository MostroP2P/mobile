import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/key_manager/providers/backup_confirmation_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class BackupReminderBanner extends ConsumerWidget {
  const BackupReminderBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBackupConfirmed = ref.watch(backupConfirmationProvider);
    
    // Don't show banner if backup is already confirmed
    if (isBackupConfirmed) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(
          color: AppTheme.statusError,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HeroIcon(
                HeroIcons.exclamationTriangle,
                style: HeroIconStyle.outline,
                size: 20,
                color: AppTheme.statusError,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  S.of(context)!.backupReminderMessage,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                context.push('/key_management');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.statusError,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                S.of(context)!.backupAccountButton,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}