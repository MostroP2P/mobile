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
                      ? AppTheme.activeColor
                      : AppTheme.textInactive,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => onToggle(!isMarketRate),
                child: Container(
                  width: 50,
                  height: 26,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isMarketRate ? AppTheme.activeColor : AppTheme.backgroundInactive,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    alignment: isMarketRate ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: Colors.black,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
