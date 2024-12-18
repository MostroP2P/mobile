import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/app/app_settings.dart';
import 'package:mostro_mobile/shared/providers/shared_preferences_provider.dart';

class AppSettingsController extends StateNotifier<AppSettings> {
  final Ref ref;

  AppSettingsController(this.ref) : super(AppSettings.intial());

  Future<void> loadSettings() async {
    final prefs = ref.read(sharedPreferencesProvider);

    final isFirstLaunch = await prefs.getBool('isFirstLaunch') ?? true;

    state = state.copyWith(isFirstLaunch: isFirstLaunch);
  }
}
