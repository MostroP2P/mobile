import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/core/app_theme.dart';

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
                    image: AssetImage('assets/images/logo.png'),
                    fit: BoxFit.scaleDown)),
            child: Stack(),
          ),
          ListTile(
            title: const Text('Key Management'),
            onTap: () {
              context.push('/key_management');
            },
          ),
          ListTile(
            title: const Text('Settings'),
            onTap: () {
              context.push('/settings');
            },
          ),
          ListTile(
            title: const Text('About'),
            onTap: () {
              context.push('/about');
            },
          ),
        ],
      ),
    );
  }
}
