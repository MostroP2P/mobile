import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/core/app_theme.dart';

class MostroAppDrawer extends StatelessWidget {
  const MostroAppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the status bar height to position drawer below app bar
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final appBarHeight = AppBar().preferredSize.height;
    
    return Drawer(
      backgroundColor: AppTheme.dark1, // Match bottom navbar color
      width: MediaQuery.of(context).size.width * 0.7, // Make drawer more compact
      child: Padding(
        padding: EdgeInsets.only(top: statusBarHeight + appBarHeight),
        child: Column(
          children: [
            // Logo header with smaller height
            Container(
              height: 120,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/logo.png'),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const Divider(height: 1, color: Colors.transparent),
            // Account option
            ListTile(
              dense: true, // Make more compact
              leading: Icon(
                Icons.person_outline_rounded, // Using rounded icons to match bottom navbar
                color: AppTheme.cream1,
                size: 22, // Smaller icon
              ),
              title: Text(
                'Account',
                style: AppTheme.theme.textTheme.bodyLarge?.copyWith(
                  color: AppTheme.cream1,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                context.push('/key_management');
                Navigator.pop(context); // Close drawer after selection
              },
            ),
            // Settings option
            ListTile(
              dense: true, // Make more compact
              leading: Icon(
                Icons.settings_rounded, // Using rounded icons to match bottom navbar
                color: AppTheme.cream1,
                size: 22, // Smaller icon
              ),
              title: Text(
                'Settings',
                style: AppTheme.theme.textTheme.bodyLarge?.copyWith(
                  color: AppTheme.cream1,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                context.push('/settings');
                Navigator.pop(context); // Close drawer after selection
              },
            ),
            // About option
            ListTile(
              dense: true, // Make more compact
              leading: Icon(
                Icons.info_rounded, // Using rounded icons to match bottom navbar
                color: AppTheme.cream1,
                size: 22, // Smaller icon
              ),
              title: Text(
                'About',
                style: AppTheme.theme.textTheme.bodyLarge?.copyWith(
                  color: AppTheme.cream1,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                context.push('/about');
                Navigator.pop(context); // Close drawer after selection
              },
            ),
            // Walkthrough option
            ListTile(
              dense: true, // Make more compact
              leading: Icon(
                Icons.menu_book_rounded, // Using rounded icons to match bottom navbar
                color: AppTheme.cream1,
                size: 22, // Smaller icon
              ),
              title: Text(
                'Walkthrough',
                style: AppTheme.theme.textTheme.bodyLarge?.copyWith(
                  color: AppTheme.cream1,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                context.push('/walkthrough');
                Navigator.pop(context); // Close drawer after selection
              },
            ),
          ],
        ),
      ),
    );
  }
}
