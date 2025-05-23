import 'package:flutter/material.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/order/widgets/form_section.dart';

class PriceTypeSection extends StatelessWidget {
  final bool isMarketRate;
  final ValueChanged<bool> onToggle;

  const PriceTypeSection({
    super.key,
    required this.isMarketRate,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    // Define the icon for the FormSection
    final priceTypeIcon = Icon(
      Icons.attach_money,
      size: 18,
      color: AppTheme.textPrimary,
    );
    
    return FormSection(
      title: 'Price type',
      icon: priceTypeIcon,
      iconBackgroundColor: AppTheme.purpleAccent.withOpacity(0.3), // Purple color consistent with other sections
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Market price',
            style: TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
          ),
          Row(
            children: [
              Text(
                'Market',
                style: TextStyle(
                  color: isMarketRate
                      ? AppTheme.statusSuccess
                      : AppTheme.textInactive,
                  fontSize: 14,
                ),
              ),
              Switch(
                value: isMarketRate,
                activeColor: AppTheme.purpleAccent, // Keep the purple accent color
                onChanged: onToggle,
              ),
            ],
          ),
        ],
      ),
      // Add info icon as extra content
      extraContent: Padding(
        padding: const EdgeInsets.only(right: 16, bottom: 8),
        child: Align(
          alignment: Alignment.centerRight,
          child: Icon(
            Icons.info_outline,
            size: 14,
            color: AppTheme.textSubtle,
          ),
        ),
      ),
    );
  }
}
