import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/data/models/notification.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class NotificationMenu extends StatelessWidget {
  final NotificationModel notification;
  final Function(String) onMenuAction;

  const NotificationMenu({
    super.key,
    required this.notification,
    required this.onMenuAction,
  });

  @override
  Widget build(BuildContext context) {
    
    return PopupMenuButton<String>(
      icon: HeroIcon(
        HeroIcons.ellipsisVertical,
        style: HeroIconStyle.outline,
        size: 16,
        color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.6),
      ),
      color: Theme.of(context).cardTheme.color,
      onSelected: onMenuAction,
      itemBuilder: (context) => [
        if (!notification.isRead) _buildMarkAsReadMenuItem(context),
        _buildDeleteMenuItem(context),
      ],
      
    );
  }

  PopupMenuItem<String> _buildMarkAsReadMenuItem(BuildContext context) {
    return PopupMenuItem(
      value: 'mark_read',
      child: Row(
        children: [
          HeroIcon(
            HeroIcons.check,
            style: HeroIconStyle.outline,
            size: 16,
            color: Theme.of(context).colorScheme.primary
          ),
          const SizedBox(width: 8),
          Text(
            S.of(context)!.markAsRead,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildDeleteMenuItem(BuildContext context) {
    return PopupMenuItem(
      value: 'delete',
      child: Row(
        children: [
          HeroIcon(
            HeroIcons.trash,
            style: HeroIconStyle.outline,
            size: 16,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 8),
          Text(
            S.of(context)!.notificationDelete,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }
}