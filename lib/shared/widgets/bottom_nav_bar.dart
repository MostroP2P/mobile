import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

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

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2C),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(
            context,
            LucideIcons.book,
            'Order Book',
            0,
          ),
          _buildNavItem(
            context,
            LucideIcons.zap,
            'My Trades',
            1,
            notificationCount: orderNotificationCount,
          ),
          _buildNavItem(
            context,
            LucideIcons.messageSquare,
            'Chat',
            2,
            notificationCount: chatCount,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
      BuildContext context, IconData icon, String label, int index,
      {int? notificationCount}) {
    bool isActive = _isActive(context, index);

    // Colores específicos basados en la imagen de React
    Color iconColor = isActive ? const Color(0xFF8CC541) : Colors.white;
    Color textColor = isActive ? const Color(0xFF8CC541) : Colors.white;

    return InkWell(
      onTap: () => _onItemTapped(context, index),
      child: SizedBox(
        width: 100,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: iconColor,
                  size: 20, // Un poco más pequeño
                ),
                if (notificationCount != null && notificationCount > 0)
                  Positioned(
                    top: -4,
                    right: -4,
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
            const SizedBox(height: 3), // Menos espacio
            Text(
              label,
              style: GoogleFonts.inter(
                // Usar la fuente Inter para un aspecto más moderno
                fontSize: 11, // Texto más pequeño
                fontWeight: FontWeight.w400, // Más ligero
                color: textColor,
                letterSpacing:
                    -0.2, // Espacio negativo entre letras para texto más condensado
              ),
            ),
          ],
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
