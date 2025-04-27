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
            leading: Icon(
              Icons.person_outline_sharp,
              color: AppTheme.cream1,
            ),
            title: Text(
              'Account',
              style: AppTheme.theme.textTheme.headlineMedium,
            ),
            onTap: () {
              context.push('/key_management');
            },
          ),
          ListTile(
            leading: Icon(
              Icons.settings_outlined,
              color: AppTheme.cream1,
            ),
            title: Text(
              'Settings',
              style: AppTheme.theme.textTheme.headlineMedium,
            ),
            onTap: () {
              context.push('/settings');
            },
          ),
          ListTile(
            leading: Icon(
              Icons.info_outlined,
              color: AppTheme.cream1,
            ),
            title: Text(
              'About',
              style: AppTheme.theme.textTheme.headlineMedium,
            ),
            onTap: () {
              context.push('/about');
            },
          ),
          ListTile(
            leading: Icon(
              Icons.menu_book_sharp,
              color: AppTheme.cream1,
            ),
            title: Text(
              'Walkthrough',
              style: AppTheme.theme.textTheme.headlineMedium,
            ),
            onTap: () {
              context.push('/walkthrough');
            },
          ),
        ],
      ),
    );
  }
}
