import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';

class OrderAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const OrderAppBar({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const HeroIcon(HeroIcons.arrowLeft, color: AppTheme.cream1),
        onPressed: () => context.go('/'),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: AppTheme.cream1,
          fontFamily: GoogleFonts.robotoCondensed().fontFamily,
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
