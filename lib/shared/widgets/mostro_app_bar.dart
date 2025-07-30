import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:mostro_mobile/shared/providers/drawer_provider.dart';

class MostroAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final Widget? title;
  final bool showBackButton;
  
  const MostroAppBar({
    super.key,
    this.title,
    this.showBackButton = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    final currentRoute = GoRouterState.of(context).uri.path;
    
    return AppBar(
      backgroundColor: AppTheme.backgroundDark,
      elevation: 0,
      leadingWidth: 70,
      title: title,
      centerTitle: title != null,
      // Add bottom border similar to bottom navbar
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(
          height: 1.0,
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      // Use a custom IconButton with specific padding
      leading: Padding(
        padding: const EdgeInsets.only(left: 16.0),
        child: IconButton(
          icon: HeroIcon(
            showBackButton ? HeroIcons.arrowLeft : HeroIcons.bars3,
            style: HeroIconStyle.outline,
            color: AppTheme.cream1,
            size: 28,
          ),
          onPressed: () {
            if (showBackButton) {
              context.pop();
            } else {
              ref.read(drawerProvider.notifier).toggleDrawer();
            }
          },
        ),
      ),
      actions: [
        // Only show notification bell if not on notifications screen
        if (currentRoute != '/notifications')
          Stack(
            children: [
              IconButton(
                icon: const HeroIcon(
                  HeroIcons.bell,
                  style: HeroIconStyle.outline,
                  color: AppTheme.cream1,
                  size: 28,
                ),
                onPressed: () {
                  context.push('/notifications');
                },
              ),
              // Notification count indicator
              if (unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppTheme.green2,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(width: 16), // Spacing
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1.0);
}
