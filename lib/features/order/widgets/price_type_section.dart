import 'package:flutter/material.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/order/widgets/form_section.dart';
import 'package:mostro_mobile/generated/l10n.dart';

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
      title: S.of(context)!.priceType,
      icon: priceTypeIcon,
      iconBackgroundColor: AppTheme.purpleAccent.withValues(
          alpha: 0.3), // Purple color consistent with other sections
      infoTooltip: S.of(context)!.priceTypeTooltip,
      infoTitle: S.of(context)!.priceType,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isMarketRate
                ? S.of(context)!.marketPrice
                : S.of(context)!.fixedPrice,
            style: const TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
          ),
          Row(
            children: [
              Text(
                S.of(context)!.market,
                style: TextStyle(
                  color: isMarketRate
                      ? AppTheme.statusSuccess
                      : AppTheme.textInactive,
                  fontSize: 14,
                ),
              ),
              Switch(
                key: const Key('fixedSwitch'),
                value: isMarketRate,
                thumbColor: WidgetStateProperty.resolveWith<Color?>(
                  (Set<WidgetState> states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppTheme.textPrimary; // White thumb when active for better contrast
                    }
                    return AppTheme.textSecondary; // Light grey when inactive
                  },
                ),
                trackColor: WidgetStateProperty.resolveWith<Color?>(
                  (Set<WidgetState> states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppTheme.purpleAccent; // Purple track when active
                    }
                    return AppTheme.backgroundInactive; // Dark grey track when inactive
                  },
                ),
                trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                onChanged: onToggle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
