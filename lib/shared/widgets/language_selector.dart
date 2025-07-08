import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class LanguageSelector extends ConsumerWidget {
  const LanguageSelector({super.key});

  static const Map<String?, String> _languageKeys = {
    null: 'systemDefault',
    'en': 'english',
    'es': 'spanish',
    'it': 'italian',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final currentLanguage = settings.selectedLanguage;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.dark1,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: currentLanguage,
          isExpanded: true,
          dropdownColor: AppTheme.dark1,
          style: const TextStyle(color: AppTheme.cream1),
          icon: const Icon(Icons.arrow_drop_down, color: AppTheme.cream1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          items: _languageKeys.entries.map((entry) {
            final languageCode = entry.key;
            final languageKey = entry.value;

            final displayName = _getLocalizedLanguageName(context, languageKey);

            return DropdownMenuItem<String?>(
              value: languageCode,
              child: Row(
                children: [
                  Icon(
                    languageCode == null ? Icons.phone_android : Icons.language,
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
          onChanged: (String? newLanguage) {
            ref
                .read(settingsProvider.notifier)
                .updateSelectedLanguage(newLanguage);
          },
        ),
      ),
    );
  }

  String _getLocalizedLanguageName(BuildContext context, String key) {
    switch (key) {
      case 'systemDefault':
        return S.of(context)!.systemDefault;
      case 'english':
        return S.of(context)!.english;
      case 'spanish':
        return S.of(context)!.spanish;
      case 'italian':
        return S.of(context)!.italian;
      default:
        return key;
    }
  }
}
