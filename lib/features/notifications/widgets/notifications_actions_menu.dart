import 'package:flutter/material.dart';
import 'package:mostro_mobile/common/top_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class NotificationsActionsMenu extends ConsumerWidget {
  const NotificationsActionsMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const HeroIcon(
        HeroIcons.ellipsisVertical,
        style: HeroIconStyle.outline,
        color: AppTheme.cream1,
        size: 24,
      ),
      color: AppTheme.backgroundDark,
      onSelected: (value) => _handleMenuAction(context, ref, value),
      itemBuilder: (context) => [
        _buildMarkAllAsReadMenuItem(context),
        _buildClearAllMenuItem(context),
      ],
    );
  }

  PopupMenuItem<String> _buildMarkAllAsReadMenuItem(BuildContext context) {
    return PopupMenuItem(
      value: 'mark_all_read',
      child: Row(
        children: [
          const HeroIcon(
            HeroIcons.checkCircle,
            style: HeroIconStyle.outline,
            size: 20,
            color: AppTheme.statusSuccess,
          ),
          const SizedBox(width: 12),
          Text(
            S.of(context)!.markAllAsRead,
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildClearAllMenuItem(BuildContext context) {
    return PopupMenuItem(
      value: 'clear_all',
      child: Row(
        children: [
          const HeroIcon(
            HeroIcons.trash,
            style: HeroIconStyle.outline,
            size: 20,
            color: AppTheme.statusError,
          ),
          const SizedBox(width: 12),
          Text(
            S.of(context)!.clearAll,
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, String action) {
    final repository = ref.read(notificationsDatabaseProvider);
    
    switch (action) {
      case 'mark_all_read':
        repository.markAllAsRead();
         showTopSnackBar(
           context,
           S.of(context)!.markAllAsRead,
           backgroundColor: AppTheme.statusSuccess,
     );
        break;
      case 'clear_all':
        _showClearAllConfirmationDialog(context, ref);
        break;
    }
  }

  void _showClearAllConfirmationDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.backgroundDark,
        title: Text(
          S.of(context)!.clearAll,
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          S.of(context)!.confirmClearAll,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              S.of(context)!.cancel,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(notificationsDatabaseProvider).clearAll();
              Navigator.of(context).pop();
              showTopSnackBar(
                context,
                S.of(context)!.clearAll,
                backgroundColor: AppTheme.statusError,
       );
            },
            child: Text(
              S.of(context)!.clearAll,
              style: const TextStyle(color: AppTheme.statusError),
            ),
          ),
        ],
      ),
    );
  }
}