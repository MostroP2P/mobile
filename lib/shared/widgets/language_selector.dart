import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';


class LanguageSelector extends ConsumerWidget {
  const LanguageSelector({super.key});

  static const Map<String?, String> _languageOptions = {
    null: 'System Default', // Will be localized in build method
    'en': 'English',
    'es': 'Español',
    'it': 'Italiano',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final currentLanguage = settings.selectedLanguage;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundInput,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.grey2, width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: currentLanguage,
          isExpanded: true,
          dropdownColor: AppTheme.backgroundInput,
          style: const TextStyle(color: AppTheme.cream1),
          icon: const Icon(Icons.arrow_drop_down, color: AppTheme.cream1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          items: _languageOptions.entries.map((entry) {
            final languageCode = entry.key;
            final languageName = entry.value;
            
            // Localize "System Default" text
            final displayName = languageCode == null 
                ? 'System Default' // Fallback text since systemDefault may not exist
                : languageName;
            
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
                  if (languageCode == currentLanguage) ...[
                    const Spacer(),
                    const Icon(
                      Icons.check,
                      color: AppTheme.mostroGreen,
                      size: 20,
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
          onChanged: (String? newLanguage) {
            ref.read(settingsProvider.notifier).updateSelectedLanguage(newLanguage);
          },
        ),
      ),
    );
  }
}
