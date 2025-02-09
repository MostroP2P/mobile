import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/shared/providers/app_init_provider.dart';

class MostroAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MostroAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF1D212C),
      elevation: 0,
      leading: IconButton(
        icon: const HeroIcon(HeroIcons.bars3,
            style: HeroIconStyle.outline, color: Colors.white),
        onPressed: () {
          Scaffold.of(context).openDrawer();
        },
      ),
      actions: [
        IconButton(
          key: Key('createOrderButton'),
          icon: const HeroIcon(HeroIcons.plus,
              style: HeroIconStyle.outline, color: Colors.white),
          onPressed: () {
            context.go('/add_order');
          },
        ),
        IconButton(
          icon: const HeroIcon(HeroIcons.bolt,
              style: HeroIconStyle.solid, color: Color(0xFF8CC541)),
          onPressed: () async {
            await clearAppData();
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
