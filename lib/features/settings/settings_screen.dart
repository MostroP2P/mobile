import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/relays/widgets/relay_selector.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/widgets/privacy_switch_widget.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

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
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            child: ListTile(
              title: Text('General Settings'),
            ),
          ),
          const SizedBox(height: 16),
          PrivacySwitch(
            initialValue: settings.fullPrivacyMode,
            onChanged: (newValue) {
              ref
                  .read(settingsProvider.notifier)
                  .updatePrivacyModeSetting(newValue);
            },
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              title: Text('Relays'),
            ),
          ),
          SizedBox(
            height: 200,
            child: RelaySelector(),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              title: Text('Mostro'),
            ),
          ),
        ],
      ),
    );
  }
}
