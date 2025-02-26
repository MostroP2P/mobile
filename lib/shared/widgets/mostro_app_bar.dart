import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/shared/providers/app_init_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';

class MostroAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const MostroAppBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      backgroundColor: AppTheme.dark1,
      elevation: 0,
      leading: IconButton(
        icon: const HeroIcon(HeroIcons.bars3,
            style: HeroIconStyle.outline, color: AppTheme.cream1),
        onPressed: () {
          Scaffold.of(context).openDrawer();
        },
      ),
      actions: [
        IconButton(
          key: Key('createOrderButton'),
          icon: const HeroIcon(HeroIcons.plus,
              style: HeroIconStyle.outline, color: AppTheme.cream1),
          onPressed: () {
            context.go('/add_order');
          },
        ),
        IconButton(
          icon: const HeroIcon(HeroIcons.bolt,
              style: HeroIconStyle.solid, color: AppTheme.yellow),
          onPressed: () async {
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
