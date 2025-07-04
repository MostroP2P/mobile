import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/shared/providers/drawer_provider.dart';

class MostroAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const MostroAppBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      backgroundColor: AppTheme.backgroundDark,
      elevation: 0,
      leadingWidth: 70,
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
          icon: const HeroIcon(
            HeroIcons.bars3,
            style: HeroIconStyle.outline,
            color: AppTheme.cream1,
            size: 28,
          ),
          onPressed: () {
            ref.read(drawerProvider.notifier).toggleDrawer();
          },
        ),
      ),
      actions: [
        // Notification with count indicator
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
                // Action for notifications
              },
            ),
            // Notification count indicator
          ],
        ),
        const SizedBox(width: 16), // Spacing
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1.0);
}
