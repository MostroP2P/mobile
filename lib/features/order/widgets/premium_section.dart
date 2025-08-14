import 'package:flutter/material.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/order/widgets/form_section.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class PremiumSection extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const PremiumSection({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Define the premium value display as the icon - showing only whole numbers
    final premiumValueIcon = Text(
      value.round().toString(),
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
    );

    // Use the FormSection for consistent styling
    return FormSection(
      title: S.of(context)!.premiumTitle,
      icon: premiumValueIcon,
      iconBackgroundColor: AppTheme.purpleAccent, // Purple color for premium
      infoTooltip: S.of(context)!.premiumTooltip,
      infoTitle: S.of(context)!.premiumTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Slider
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppTheme.purpleAccent,
              inactiveTrackColor: AppTheme.backgroundInactive,
              thumbColor: AppTheme.textPrimary,
              overlayColor: AppTheme.purpleAccent.withValues(alpha: 0.2),
              trackHeight: 4,
            ),
            child: Slider(
              key: const Key('premiumSlider'),
              value: value,
              min: -10,
              max: 10,
              divisions: 20,
              onChanged: onChanged,
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  '-10%',
                  style: TextStyle(color: AppTheme.statusError, fontSize: 12),
                ),
                Text(
                  '+10%',
                  style: TextStyle(color: AppTheme.statusSuccess, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
