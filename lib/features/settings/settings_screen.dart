import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_ui/flutter_settings_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/relays/widgets/relay_selector.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    const settingsThemeData = SettingsThemeData(
      settingsListBackground: AppTheme.dark2,
      settingsSectionBackground: AppTheme.dark1,
      titleTextColor: AppTheme.cream1,
      settingsTileTextColor: AppTheme.cream1,
      leadingIconsColor: AppTheme.cream1,
      tileDescriptionTextColor: AppTheme.grey,
    );
    final mostroTextContoller =
        TextEditingController(text: settings.mostroInstance);

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
      body: SettingsList(
        lightTheme: settingsThemeData,
        sections: [
          SettingsSection(
            title: Text(
              'General Settings',
              style: AppTheme.theme.textTheme.displayMedium,
            ),
            tiles: [
              SettingsTile.switchTile(
                title: Text('Full Privacy Mode'),
                leading: HeroIcon(HeroIcons.eye),
                initialValue: settings.fullPrivacyMode,
                onToggle: (bool value) {
                  ref
                      .watch(settingsProvider.notifier)
                      .updatePrivacyModeSetting(value);
                },
              ),
            ],
          ),
          SettingsSection(
            title: Text(
              'Relays',
              style: AppTheme.theme.textTheme.displayMedium,
            ),
            tiles: [
              CustomSettingsTile(
                child: SizedBox(
                  height: 256,
                  child: RelaySelector(),
                ),
              ),
            ],
          ),
          SettingsSection(
            title: Text(
              'Mostro',
              style: AppTheme.theme.textTheme.displayMedium,
            ),
            tiles: [
              CustomSettingsTile(
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: 24,
                    end: 24,
                    bottom: 19,
                    top: 19,
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: mostroTextContoller,
                        ),
                      ]),
                ),
              )
            ],
          ),
        ],
      ),
    );
  }
}
