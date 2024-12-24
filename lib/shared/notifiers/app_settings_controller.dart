import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/app/app_settings.dart';
import 'package:mostro_mobile/data/models/enums/storage_keys.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';

class AppSettingsController extends StateNotifier<AppSettings> {
  final Ref ref;

  AppSettingsController(this.ref) : super(AppSettings.intial());

  Future<void> loadSettings() async {
    final prefs = ref.read(sharedPreferencesProvider);

    final fullPrivacyMode =
        await prefs.getBool(SharedPreferencesKeys.fullPrivacy.toString()) ??
            true;

    state = state.copyWith(fullPrivacyMode: fullPrivacyMode);
  }
}
