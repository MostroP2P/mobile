import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/data/models/enums/storage_keys.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';

class SettingsController extends StateNotifier<Settings> {
  final Ref ref;

  SettingsController(this.ref) : super(Settings.intial());

  Future<void> loadSettings() async {
    final prefs = ref.read(sharedPreferencesProvider);

    final fullPrivacyMode =
        await prefs.getBool(SharedPreferencesKeys.fullPrivacy.toString()) ??
            true;

    state = state.copyWith(fullPrivacyMode: fullPrivacyMode);
  }
}
