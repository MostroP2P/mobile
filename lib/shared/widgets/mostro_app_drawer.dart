import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mostro_mobile/app/app_theme.dart';

class MostroAppDrawer extends StatelessWidget {
  const MostroAppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppTheme.dark2,
      child: ListView(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
                color: AppTheme.dark1,
                image: const DecorationImage(
                    image: AssetImage("assets/images/mostro-icons.png"),
                    fit: BoxFit.scaleDown)),
            child: Stack(
              children: [
                Positioned(
                  bottom: 8.0,
                  left: 4.0,
                  child: Text(
                    "Mostro",
                    style: TextStyle(
                      color: AppTheme.cream1,
                      fontFamily: GoogleFonts.robotoCondensed().fontFamily,
                    ),
                  ),
                )
              ],
            ),
          ),
          ListTile(
            title: const Text('Relays'),
            onTap: () {
              context.go('/relays');
            },
          ),
          ListTile(
            title: const Text('Key Management'),
            onTap: () {
              context.go('/key_management');
            },
          ),
        ],
      ),
    );
  }
}
