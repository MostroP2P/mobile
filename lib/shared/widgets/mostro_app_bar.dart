import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/shared/providers/drawer_provider.dart';
import 'package:mostro_mobile/shared/widgets/notification_history_bell_widget.dart';

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
          color: AppTheme.textInactive.withValues(alpha: 0.1),
        ),
      ),
      leading: Padding(
        padding: AppTheme.mediumPadding.copyWith(top: 0, bottom: 0),
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
        const NotificationBellWidget(),
        SizedBox(width: AppTheme.mediumPadding.horizontal),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1.0);
}
