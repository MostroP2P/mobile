import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/presentation/home/screens/home_screen.dart';
import 'package:mostro_mobile/presentation/chat_list/screens/chat_list_screen.dart';

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
          color: isActive ? Colors.white : Colors.black,
          size: 24,
        ),
      ),
    );
  }

  bool _isActive(BuildContext context, int index) {
    if (index == 0 && context.widget is HomeScreen) return true;
    if (index == 1 && context.widget is ChatListScreen) return true;
    return false;
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ChatListScreen()),
        );
        break;
      case 2:
        // TODO: Implementar pantalla de perfil
        break;
    }
  }
}
