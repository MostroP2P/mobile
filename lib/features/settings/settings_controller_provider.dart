import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_controller.dart';

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, Settings>((ref) {
  return SettingsController(ref);
});
