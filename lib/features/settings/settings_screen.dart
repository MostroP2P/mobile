import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/relays/widgets/relay_selector.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/widgets/currency_combo_box.dart';
import 'package:mostro_mobile/shared/widgets/custom_card.dart';
import 'package:mostro_mobile/shared/widgets/language_selector.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final mostroTextContoller =
        TextEditingController(text: settings.mostroPublicKey);
    final textTheme = AppTheme.theme.textTheme;

    return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const HeroIcon(HeroIcons.arrowLeft, color: AppTheme.cream1),
            onPressed: () => context.pop(),
          ),
          title: Text(
            S.of(context)!.settings,
            style: TextStyle(
              color: AppTheme.cream1,
            ),
          ),
        ),
        backgroundColor: AppTheme.dark1,
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: AppTheme.largePadding,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 24,
                    children: [
                      // Language Settings
                      CustomCard(
                        color: AppTheme.dark2,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          spacing: 16,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              spacing: 8,
                              children: [
                                const Icon(
                                  Icons.language,
                                  color: AppTheme.mostroGreen,
                                ),
                                Text(S.of(context)!.language,
                                    style: textTheme.titleLarge),
                              ],
                            ),
                            Text(S.of(context)!.chooseLanguageDescription,
                                style: textTheme.bodyMedium
                                    ?.copyWith(color: AppTheme.grey2)),
                            const LanguageSelector(),
                          ],
                        ),
                      ),
                      // Currency Settings
                      CustomCard(
                        color: AppTheme.dark2,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          spacing: 16,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              spacing: 8,
                              children: [
                                const Icon(
                                  Icons.toll,
                                  color: AppTheme.mostroGreen,
                                ),
                                Text(S.of(context)!.currency,
                                    style: textTheme.titleLarge),
                              ],
                            ),
                            Text(S.of(context)!.setDefaultFiatCurrency,
                                style: textTheme.bodyMedium
                                    ?.copyWith(color: AppTheme.grey2)),
                            CurrencyComboBox(
                              label: S.of(context)!.defaultFiatCurrency,
                              onSelected: (fiatCode) {
                                ref
                                    .watch(settingsProvider.notifier)
                                    .updateDefaultFiatCode(fiatCode);
                              },
                            ),
                          ],
                        ),
                      ),
                      CustomCard(
                        color: AppTheme.dark2,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          spacing: 16,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              spacing: 8,
                              children: [
                                const Icon(
                                  Icons.sensors,
                                  color: AppTheme.mostroGreen,
                                ),
                                Text(S.of(context)!.relays,
                                    style: textTheme.titleLarge),
                              ],
                            ),
                            Text(S.of(context)!.selectNostrRelays,
                                style: textTheme.bodyMedium
                                    ?.copyWith(color: AppTheme.grey2)),
                            RelaySelector(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    RelaySelector.showAddDialog(context, ref);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.mostroGreen,
                                  ),
                                  child: Text(S.of(context)!.addRelay),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      CustomCard(
                        color: AppTheme.dark2,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          spacing: 16,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              spacing: 8,
                              children: [
                                const Icon(
                                  Icons.flash_on,
                                  color: AppTheme.mostroGreen,
                                ),
                                Text(S.of(context)!.mostro,
                                    style: textTheme.titleLarge),
                              ],
                            ),
                            Text(S.of(context)!.enterMostroPublicKey,
                                style: textTheme.bodyMedium
                                    ?.copyWith(color: AppTheme.grey2)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.dark1,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: TextFormField(
                                key: key,
                                controller: mostroTextContoller,
                                style: const TextStyle(color: AppTheme.cream1),
                                onChanged: (value) => ref
                                    .watch(settingsProvider.notifier)
                                    .updateMostroInstance(value),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  labelText: S.of(context)!.mostroPubkey,
                                  labelStyle:
                                      const TextStyle(color: AppTheme.grey2),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]),
              ),
            ),
          ],
        ));
  }
}
