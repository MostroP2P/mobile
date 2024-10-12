import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/routes/app_routes.dart';

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
              _buildNavItem(context, HeroIcons.chatBubbleOvalLeft, 1),
              _buildNavItem(context, HeroIcons.user, 2),
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
    final currentRoute = ModalRoute.of(context)?.settings.name;
    switch (index) {
      case 0:
        return currentRoute == AppRoutes.home;
      case 1:
        return currentRoute == AppRoutes.chatList;
      case 2:
        return currentRoute == AppRoutes.profile;
      default:
        return false;
    }
  }

  void _onItemTapped(BuildContext context, int index) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    String nextRoute;

    switch (index) {
      case 0:
        nextRoute = AppRoutes.home;
        break;
      case 1:
        nextRoute = AppRoutes.chatList;
        break;
      case 2:
        nextRoute = AppRoutes.profile;
        break;
      default:
        return;
    }

    if (currentRoute != nextRoute) {
      Navigator.pushReplacementNamed(context, nextRoute);
    }
  }
}
