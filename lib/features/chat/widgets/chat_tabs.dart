import 'package:flutter/material.dart';
import 'package:mostro_mobile/core/app_theme.dart';

class ChatTabs extends StatelessWidget {
  final TabController tabController;
  final VoidCallback onTabChanged;

  const ChatTabs({
    super.key,
    required this.tabController,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          _buildTabButton(context, 0, "Messages", tabController.index == 0),
          _buildTabButton(context, 1, "Disputes", tabController.index == 1),
        ],
      ),
    );
  }

  Widget _buildTabButton(
      BuildContext context, int index, String text, bool isActive) {
    return Expanded(
      child: InkWell(
        onTap: () {
          tabController.animateTo(index);
          onTabChanged();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? AppTheme.mostroGreen : Colors.transparent,
                width: 3.0,
              ),
            ),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? AppTheme.mostroGreen : AppTheme.textInactive,
              fontWeight: FontWeight.w600,
              fontSize: 15,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}