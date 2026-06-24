import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/shared/providers/drawer_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class CustomDrawerOverlay extends ConsumerWidget {
  final Widget child;

  const CustomDrawerOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDrawerOpen = ref.watch(drawerProvider);
    final statusBarHeight = MediaQuery.of(context).padding.top;

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
              color: Colors.black.withValues(alpha: 0.3),
            ),
          ),

        // Drawer
        PopScope(
          canPop: !isDrawerOpen,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && isDrawerOpen) {
              // Close drawer if it's open
              ref.read(drawerProvider.notifier).closeDrawer();
            }
          },
          child: AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: isDrawerOpen ? 0 : -MediaQuery.of(context).size.width * 0.7,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity != null &&
                    details.primaryVelocity! < 0) {
                  ref.read(drawerProvider.notifier).closeDrawer();
                }
              },
              child: Container(
                width: MediaQuery.of(context).size.width * 0.7,
                decoration: BoxDecoration(
                  color: AppTheme.dark1,
                  border: Border(
                    right: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1.0,
                    ),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.only(top: statusBarHeight),
                  child: Column(
                    children: [
                      SizedBox(height: 24),

                      // Logo header
                      Container(
                        height: 100,
                        width: double.infinity,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage('assets/images/logo-beta.png'),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                      SizedBox(height: 24),

                      Divider(
                        height: 1,
                        thickness: 1,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),

                      SizedBox(height: 16),

                      // Menu items
                      _buildMenuItem(
                        context,
                        ref,
                        icon: LucideIcons.user,
                        title: S.of(context)!.account,
                        route: '/key_management',
                      ),
                      _buildMenuItem(
                        context,
                        ref,
                        icon: LucideIcons.settings,
                        title: S.of(context)!.settings,
                        route: '/settings',
                      ),
                      _buildMenuItem(
                        context,
                        ref,
                        icon: LucideIcons.info,
                        title: S.of(context)!.about,
                        route: '/about',
                      ),
                    ],
                  ),
                ),
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
