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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildInfoButton(context, S.of(context)!.tradeInformation, "trade"),
          const SizedBox(width: 8),
          _buildInfoButton(context, S.of(context)!.userInformation, "user"),
        ],
      ),
    );
  }

  Widget _buildInfoButton(BuildContext context, String title, String type) {
    final isSelected = selectedInfoType == type;

    return Expanded(
      child: ElevatedButton(
        onPressed: () {
          onInfoTypeChanged(isSelected ? null : type);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected
              ? AppTheme.mostroGreen.withValues(alpha: 0.2)
              : AppTheme.backgroundCard,
          foregroundColor:
              isSelected ? AppTheme.mostroGreen : AppTheme.textSecondary,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isSelected ? AppTheme.mostroGreen : Colors.transparent,
              width: 1,
            ),
          ),
          elevation: 0,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                type == 'trade'
                    ? Icons.description_outlined
                    : Icons.person_outline,
                size: 18,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}