import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:mostro_mobile/features/notifications/providers/backup_reminder_provider.dart';

class NotificationBellWidget extends ConsumerStatefulWidget {
  const NotificationBellWidget({super.key});

  @override
  ConsumerState<NotificationBellWidget> createState() => _NotificationBellWidgetState();
}

class _NotificationBellWidgetState extends ConsumerState<NotificationBellWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(
      begin: -0.05,
      end: 0.05,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticIn,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    final shouldShowBackupReminder = ref.watch(backupReminderProvider);
    final currentRoute = GoRouterState.of(context).uri.path;

    if (currentRoute == '/notifications') {
      return const SizedBox.shrink();
    }

    // Start shake animation if backup reminder is active
    if (shouldShowBackupReminder && !_animationController.isAnimating) {
      _animationController.repeat(reverse: true);
    } else if (!shouldShowBackupReminder && _animationController.isAnimating) {
      _animationController.stop();
      _animationController.reset();
    }

    return Stack(
      children: [
        AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            return Transform.rotate(
              angle: shouldShowBackupReminder ? _shakeAnimation.value : 0,
              child: IconButton(
                icon: const HeroIcon(
                  HeroIcons.bell,
                  style: HeroIconStyle.outline,
                  color: AppTheme.cream1,
                  size: 28,
                ),
                onPressed: () => context.push('/notifications'),
              ),
            );
          },
        ),
        if (shouldShowBackupReminder && unreadCount == 0) 
          const _BackupReminderDot()
        else if (unreadCount > 0) 
          _NotificationBadge(count: unreadCount),
      ],
    );
  }
}

class _BackupReminderDot extends StatelessWidget {
  const _BackupReminderDot();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 8,
      top: 8,
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _NotificationBadge extends StatelessWidget {
  final int count;

  const _NotificationBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 6,
      top: 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.statusPendingBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        constraints: const BoxConstraints(
          minWidth: 12,
          minHeight: 12,
        ),
        child: Text(
          count > 99 ? '99+' : count.toString(),
          style: const TextStyle(
            color: AppTheme.statusPendingText,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}