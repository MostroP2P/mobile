import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/shared/providers/drawer_provider.dart';

class CustomDrawerOverlay extends ConsumerWidget {
  final Widget child;

  const CustomDrawerOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDrawerOpen = ref.watch(drawerProvider);
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final appBarHeight = AppBar().preferredSize.height;

    return Stack(
      children: [
        // Main content
        child,

        // Overlay background
        if (isDrawerOpen)
          GestureDetector(
            onTap: () => ref.read(drawerProvider.notifier).closeDrawer(),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withOpacity(0.3),
            ),
          ),

        // Drawer
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          left: isDrawerOpen ? 0 : -MediaQuery.of(context).size.width * 0.7,
          top: 0,
          bottom: 0,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.7,
            decoration: BoxDecoration(
              color: AppTheme.dark1,
              border: Border(
                right: BorderSide(
                  color: Colors.white.withAlpha(10),
                  width: 1.0,
                ),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(top: statusBarHeight + appBarHeight),
              child: Column(
                children: [
                  // Logo header
                  Container(
                    height: 80,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/images/logo.png'),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Colors.transparent),

                  // Menu items
                  _buildMenuItem(
                    context,
                    ref,
                    icon: LucideIcons.user,
                    title: 'Account',
                    route: '/key_management',
                  ),
                  _buildMenuItem(
                    context,
                    ref,
                    icon: LucideIcons.settings,
                    title: 'Settings',
                    route: '/settings',
                  ),
                  _buildMenuItem(
                    context,
                    ref,
                    icon: LucideIcons.info,
                    title: 'About',
                    route: '/about',
                  ),
                  _buildMenuItem(
                    context,
                    ref,
                    icon: LucideIcons.bookOpen,
                    title: 'Walkthrough',
                    route: '/walkthrough',
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    WidgetRef ref, {
    required IconData icon,
    required String title,
    required String route,
  }) {
    return ListTile(
      dense: true,
      leading: Icon(
        icon,
        color: AppTheme.cream1,
        size: 22,
      ),
      title: Text(
        title,
        style: AppTheme.theme.textTheme.bodyLarge?.copyWith(
          color: AppTheme.cream1,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () {
        ref.read(drawerProvider.notifier).closeDrawer();
        context.push(route);
      },
    );
  }
}
