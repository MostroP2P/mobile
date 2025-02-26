import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/relays/widgets/relay_selector.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/widgets/currency_combo_box.dart';
import 'package:mostro_mobile/shared/widgets/privacy_switch_widget.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final mostroTextContoller =
        TextEditingController(text: settings.mostroInstance);
    final textTheme = AppTheme.theme.textTheme;

    return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const HeroIcon(HeroIcons.arrowLeft, color: AppTheme.cream1),
            onPressed: () => context.pop(),
          ),
          title: const Text(
            'SETTINGS',
            style: TextStyle(
              color: AppTheme.cream1,
            ),
          ),
        ),
        backgroundColor: AppTheme.dark1,
        body: Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.dark2,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: SingleChildScrollView(
                  padding: AppTheme.largePadding,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // General Settings
                        Text('General Settings', style: textTheme.titleLarge),
                        const SizedBox(height: 8),
                        PrivacySwitch(
                            initialValue: settings.fullPrivacyMode,
                            onChanged: (bool value) {
                              ref
                                  .watch(settingsProvider.notifier)
                                  .updatePrivacyModeSetting(value);
                            }),
                        const SizedBox(height: 8),
                        CurrencyComboBox(
                          label: "Default Fiat Currency",
                          onSelected: (fiatCode) {
                            ref
                                .watch(settingsProvider.notifier)
                                .updateDefaultFiatCodeSetting(fiatCode);
                          },
                        ),
                        const SizedBox(height: 8),
                        const Divider(color: AppTheme.grey2),
                        const SizedBox(height: 16),
                        // Relays
                        Text('Relays', style: textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.dark1,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: RelaySelector(),
                        ),
                        const SizedBox(height: 12),
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
                              child: const Text('Add Relay'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Mostro
                        const Divider(color: AppTheme.grey2),
                        const SizedBox(height: 16),
                        Text('Mostro', style: textTheme.titleLarge),
                        const SizedBox(height: 8),
                        TextFormField(
                          key: key,
                          controller: mostroTextContoller,
                          style: const TextStyle(color: AppTheme.cream1),
                          onChanged: (value) => ref
                              .watch(settingsProvider.notifier)
                              .updateMostroInstanceSetting(value),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            labelText: 'Mostro Pubkey',
                            labelStyle: const TextStyle(color: AppTheme.grey2),
                          ),
                        )
                      ]),
                ),
              ),
            ),
          ],
        ));
  }
}
