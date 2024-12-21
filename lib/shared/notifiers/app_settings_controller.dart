import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/app/app_settings.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';

class AppSettingsController extends StateNotifier<AppSettings> {
  final Ref ref;

  AppSettingsController(this.ref) : super(AppSettings.intial());

  Future<void> loadSettings() async {
    final prefs = ref.read(sharedPreferencesProvider);

    final fullPrivacyMode = await prefs.getBool('full_privacy_mode') ?? true;

    state = state.copyWith(fullPrivacyMode: fullPrivacyMode);
  }
}
