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
      leading: IconButton(
        icon: const HeroIcon(HeroIcons.bars3,
            style: HeroIconStyle.outline, color: AppTheme.cream1),
        onPressed: () {
          Scaffold.of(context).openDrawer();
        },
      ),
      actions: [
        // Eliminamos el botón de agregar (plus)
        // Mantenemos solo el icono bolt si lo necesitas
        IconButton(
          icon: const HeroIcon(HeroIcons.bolt,
              style: HeroIconStyle.solid, color: AppTheme.yellow),
          onPressed: () {
            // Acción del icono bolt
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
