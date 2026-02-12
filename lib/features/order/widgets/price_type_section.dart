import 'package:flutter/material.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/order/widgets/form_section.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/widgets/mostro_switch.dart';

class PriceTypeSection extends StatelessWidget {
  final bool isMarketRate;
  final ValueChanged<bool> onToggle;
  final String? errorMessage;

  const PriceTypeSection({
    super.key,
    required this.isMarketRate,
    required this.onToggle,
    this.errorMessage,
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
      iconBackgroundColor: AppTheme.mostroGreen.withValues(alpha: 0.3),
      infoTooltip: S.of(context)!.priceTypeTooltip,
      infoTitle: S.of(context)!.priceType,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  MostroSwitch(
                    key: const Key('fixedSwitch'),
                    value: isMarketRate,
                    onChanged: onToggle,
                  ),
                ],
              ),
            ],
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.statusError.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.statusError.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AppTheme.statusError,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(
                        color: AppTheme.statusError,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
