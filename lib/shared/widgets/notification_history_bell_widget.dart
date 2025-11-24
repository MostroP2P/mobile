import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/key_manager/providers/backup_confirmation_provider.dart';
import 'package:mostro_mobile/features/notifications/providers/notifications_provider.dart';

class NotificationBellWidget extends ConsumerStatefulWidget {
  const NotificationBellWidget({super.key});

  @override
  ConsumerState<NotificationBellWidget> createState() => _NotificationBellWidgetState();
}

class _NotificationBellWidgetState extends ConsumerState<NotificationBellWidget>
    with TickerProviderStateMixin {
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: -0.1,
      end: 0.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.elasticInOut,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _startPulseAnimation() {
    if (_isAnimating) return;
    _isAnimating = true;
    _pulseController.repeat(reverse: true);
  }

  void _stopPulseAnimation() {
    if (!_isAnimating) return;
    _isAnimating = false;
    _pulseController.stop();
    _pulseController.reset();
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    final isBackupConfirmed = ref.watch(backupConfirmationProvider);
    final currentRoute = GoRouterState.of(context).uri.path;

    // Manage animation based on backup status
    if (!isBackupConfirmed && !_isAnimating) {
      _startPulseAnimation();
    } else if (isBackupConfirmed && _isAnimating) {
      _stopPulseAnimation();
    }

    if (currentRoute == '/notifications') {
      return const SizedBox.shrink();
    }

    Widget bellIcon = HeroIcon(
      HeroIcons.bell,
      style: HeroIconStyle.outline,
      color: AppTheme.cream1,
      size: 28,
    );

    // Wrap with animation if backup not confirmed
    if (!isBackupConfirmed) {
      bellIcon = AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.rotate(
            angle: _pulseAnimation.value,
            child: child,
          );
        },
        child: bellIcon,
      );
    }

    return Stack(
      children: [
        IconButton(
          icon: bellIcon,
          onPressed: () => context.push('/notifications'),
        ),
        if (unreadCount > 0) _NotificationBadge(count: unreadCount),
        // Show red dot for backup reminder when backup not confirmed
        if (!isBackupConfirmed) const _BackupReminderDot(),
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

class _BackupReminderDot extends StatelessWidget {
  const _BackupReminderDot();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 8,
      top: 8,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppTheme.statusError,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}