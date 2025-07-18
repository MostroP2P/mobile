import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/generated/l10n.dart';

final chatCountProvider = StateProvider<int>((ref) => 0);
final orderBookNotificationCountProvider = StateProvider<int>((ref) => 0);

class BottomNavBar extends ConsumerWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the notification counts.
    final int chatCount = ref.watch(chatCountProvider);
    final int orderNotificationCount =
        ref.watch(orderBookNotificationCountProvider);

    return SafeArea(
      top: false,
      bottom: true,
      child: Container(
        width: double.infinity,
        height: 80,
        decoration: BoxDecoration(
          color: AppTheme.backgroundNavBar,
          border: Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(
              context,
              LucideIcons.book,
              S.of(context)!.orderBook,
              0,
            ),
            _buildNavItem(
              context,
              LucideIcons.zap,
              S.of(context)!.myTrades,
              1,
              notificationCount: orderNotificationCount,
            ),
            _buildNavItem(
              context,
              LucideIcons.messageSquare,
              S.of(context)!.chat,
              2,
              notificationCount: chatCount,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
      BuildContext context, IconData icon, String label, int index,
      {int? notificationCount}) {
    bool isActive = _isActive(context, index);

    Color iconColor = isActive ? AppTheme.activeColor : Colors.white;
    Color textColor = isActive ? AppTheme.activeColor : Colors.white;

    return Expanded(
      child: Semantics(
        button: true,
        enabled: true,
        label: S.of(context)!.navigateToLabel(label),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onItemTapped(context, index),
            borderRadius: BorderRadius.circular(8),
            splashColor: AppTheme.activeColor.withValues(alpha: 0.1),
            highlightColor: AppTheme.activeColor.withValues(alpha: 0.05),
            child: SizedBox(
              height: double.infinity,
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          icon,
                          color: iconColor,
                          size: 24,
                        ),
                        if (notificationCount != null && notificationCount > 0)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: textColor,
                      height: 1.0,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isActive(BuildContext context, int index) {
    final currentLocation = GoRouterState.of(context).uri.toString();
    switch (index) {
      case 0:
        return currentLocation == '/';
      case 1:
        return currentLocation == '/order_book';
      case 2:
        return currentLocation == '/chat_list';
      default:
        return false;
    }
  }

  void _onItemTapped(BuildContext context, int index) {
    String nextRoute;
    switch (index) {
      case 0:
        nextRoute = '/';
        break;
      case 1:
        nextRoute = '/order_book';
        break;
      case 2:
        nextRoute = '/chat_list';
        break;
      default:
        return;
    }

    final currentLocation = GoRouterState.of(context).uri.toString();
    if (currentLocation != nextRoute) {
      context.push(nextRoute);
    }
  }
}
