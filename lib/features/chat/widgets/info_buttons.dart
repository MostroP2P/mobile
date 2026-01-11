import 'package:flutter/material.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class InfoButtons extends StatelessWidget {
  final String? selectedInfoType;
  final ValueChanged<String?> onInfoTypeChanged;

  const InfoButtons({
    super.key,
    required this.selectedInfoType,
    required this.onInfoTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _buildInfoButton(context, S.of(context)!.tradeInformation, "trade"),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildInfoButton(context, S.of(context)!.userInformation, "user"),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoButton(BuildContext context, String title, String type) {
    final isSelected = selectedInfoType == type;
    final textLength = title.length;
    final textScaler = MediaQuery.of(context).textScaler;
    
    // Adjust font size based on text length and scale factor
    final baseFontSize = textLength > 15 ? 13.0 : 14.0;
    final fontSize = baseFontSize / textScaler.scale(1.0).clamp(0.8, 1.5);

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ElevatedButton(
        onPressed: () => onInfoTypeChanged(isSelected ? null : type),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected
              ? AppTheme.mostroGreen
              : AppTheme.backgroundCard,
          foregroundColor: isSelected ? const Color(0xFF1A1A1A) : AppTheme.textSecondary,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isSelected ? AppTheme.mostroGreen : Colors.transparent,
              width: 1,
            ),
          ),
          elevation: 0,
          minimumSize: const Size(0, 44), // Minimum tap target size
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          animationDuration: Duration.zero,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'trade' ? Icons.description_outlined : Icons.person_outline,
              size: 18,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  height: 1.2,
                  letterSpacing: 0.1,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textScaler: TextScaler.noScaling,
              ),
            ),
          ],
        ),
      ),
    );
  }
}