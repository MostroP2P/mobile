import 'package:flutter/material.dart';
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
              _buildNavItem(HeroIcons.bookOpen, true),
              _buildNavItem(HeroIcons.chatBubbleOvalLeft, false),
              _buildNavItem(HeroIcons.user, false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(HeroIcons icon, bool isActive) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF8CC541) : Colors.transparent,
        borderRadius: BorderRadius.circular(28),
      ),
      child: HeroIcon(
        icon,
        style: HeroIconStyle.outline,
        color: isActive ? Colors.white : Colors.black,
        size: 24,
      ),
    );
  }
}
