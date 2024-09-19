import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF1D212C),
      elevation: 0,
      leading: IconButton(
        icon: const HeroIcon(HeroIcons.bars3,
            style: HeroIconStyle.outline, color: Colors.white),
        onPressed: () {
          // TODO: Implement drawer opening
        },
      ),
      actions: [
        IconButton(
          icon: const HeroIcon(HeroIcons.plus,
              style: HeroIconStyle.outline, color: Colors.white),
          onPressed: () {
            // TODO: Implement new order creation
          },
        ),
        IconButton(
          icon: const HeroIcon(HeroIcons.bolt,
              style: HeroIconStyle.solid, color: Color(0xFF8CC541)),
          onPressed: () {
            // TODO: Implement profile action
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
