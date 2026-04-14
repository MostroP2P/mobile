import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class TradeHistorySelector extends ConsumerWidget {
  const TradeHistorySelector({super.key});

  static const Map<int, String> _optionKeys = {
    168: 'oneWeek',
    720: 'oneMonth',
    2160: 'threeMonths',
    4320: 'sixMonths',
    8760: 'oneYear',
    0: 'never',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final currentValue = settings.sessionExpirationHours;

    // Map null (no user preference) to Config default, which is 720
    final effectiveValue = currentValue ?? Config.sessionExpirationHours;
    // If stored value doesn't match any preset, fall back to config default
    final defaultValue = _optionKeys.containsKey(Config.sessionExpirationHours)
        ? Config.sessionExpirationHours
        : _optionKeys.keys.first;
    final displayValue =
        _optionKeys.containsKey(effectiveValue) ? effectiveValue : defaultValue;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.dark1,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: displayValue,
          isExpanded: true,
          dropdownColor: AppTheme.dark1,
          style: const TextStyle(color: AppTheme.cream1),
          icon: const Icon(Icons.arrow_drop_down, color: AppTheme.cream1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          items: _optionKeys.entries.map((entry) {
            final hours = entry.key;
            final labelKey = entry.value;
            final displayName = _getLocalizedLabel(context, labelKey);

            return DropdownMenuItem<int>(
              value: hours,
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule,
                    color: AppTheme.mostroGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: AppTheme.cream1,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (int? newValue) {
            if (newValue != null && newValue != displayValue) {
              _showConfirmationDialog(context, ref, newValue);
            }
          },
        ),
      ),
    );
  }

  void _showConfirmationDialog(
      BuildContext context, WidgetRef ref, int newValue) {
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.dark1,
        title: Text(
          S.of(context)!.tradeHistory,
          style: const TextStyle(color: AppTheme.cream1),
        ),
        content: Text(
          S.of(context)!.tradeHistoryInfoText,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              S.of(context)!.cancel,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(settingsProvider.notifier)
                  .updateSessionExpirationHours(newValue);
              Navigator.of(dialogContext).pop();
            },
            child: Text(
              S.of(context)!.confirm,
              style: const TextStyle(color: AppTheme.mostroGreen),
            ),
          ),
        ],
      ),
    );
  }

  String _getLocalizedLabel(BuildContext context, String key) {
    switch (key) {
      case 'oneWeek':
        return S.of(context)!.oneWeek;
      case 'oneMonth':
        return S.of(context)!.oneMonth;
      case 'threeMonths':
        return S.of(context)!.threeMonths;
      case 'sixMonths':
        return S.of(context)!.sixMonths;
      case 'oneYear':
        return S.of(context)!.oneYear;
      case 'never':
        return S.of(context)!.never;
      default:
        return key;
    }
  }
}
