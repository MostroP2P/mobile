import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/app/app_settings.dart';
import 'package:mostro_mobile/shared/notifiers/app_settings_controller.dart';

final appSettingsControllerProvider =
    StateNotifierProvider<AppSettingsController, AppSettings>((ref) {
  return AppSettingsController(ref);
});