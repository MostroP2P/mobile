import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/notifications/providers/notifications_provider.dart';

class NotificationBellWidget extends ConsumerWidget {
  const NotificationBellWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    final currentRoute = GoRouterState.of(context).uri.path;

    if (currentRoute == '/notifications') {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        IconButton(
          icon: const HeroIcon(
            HeroIcons.bell,
            style: HeroIconStyle.outline,
            color: AppTheme.cream1,
            size: 28,
          ),
          onPressed: () => context.push('/notifications'),
        ),
        if (unreadCount > 0) _NotificationBadge(count: unreadCount),
      ],
    );
  }
}

class _NotificationBadge extends StatelessWidget {
  final int count;

  const _NotificationBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 8,
      top: 8,
      child: Container(
        padding: AppTheme.smallPadding,
        decoration: BoxDecoration(
          color: AppTheme.statusSuccess,
          borderRadius: BorderRadius.circular(10),
        ),
        constraints: const BoxConstraints(
          minWidth: 16,
          minHeight: 16,
        ),
        child: Text(
          count > 99 ? '99+' : count.toString(),
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}