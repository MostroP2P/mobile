// lib/shared/widgets/mostro_app_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';

class MostroAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const MostroAppBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      backgroundColor: AppTheme.dark1,
      elevation: 0,
      leadingWidth: 70,
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
            Scaffold.of(context).openDrawer();
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
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    '6',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
