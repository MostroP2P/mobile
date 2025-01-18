import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          height: 56,
          width: 240,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(context, HeroIcons.bookOpen, 0),
              _buildNavItem(context, HeroIcons.bookmarkSquare, 1),
              _buildNavItem(context, HeroIcons.chatBubbleLeftRight, 2),
              _buildNavItem(context, HeroIcons.bolt, 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, HeroIcons icon, int index) {
    bool isActive = _isActive(context, index);
    return GestureDetector(
      onTap: () => _onItemTapped(context, index),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF8CC541) : Colors.transparent,
          borderRadius: BorderRadius.circular(28),
        ),
        child: HeroIcon(
          icon,
          style: HeroIconStyle.outline,
          color: Colors.black,
          size: 24,
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
        return currentLocation == '/my_trades';
      case 2:
        return currentLocation == '/chat_list';
      case 3:
        return currentLocation == '/profile';
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
        nextRoute = '/my_trades';
        break;
      case 2:
        nextRoute = '/chat_list';
        break;
      case 3:
        nextRoute = '/profile';
        break;
      default:
        return;
    }

    final currentLocation = GoRouterState.of(context).uri.toString();
    if (currentLocation != nextRoute) {
      context.go(nextRoute);
    }
  }
}
