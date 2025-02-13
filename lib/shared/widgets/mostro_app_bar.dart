import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/shared/providers/app_init_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';

class MostroAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const MostroAppBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            final mostroStorage = ref.watch(mostroStorageProvider);
            await clearAppData(mostroStorage);
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
