import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mostro_mobile/data/models/enums/storage_keys.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';

class FirstRunNotifier extends StateNotifier<AsyncValue<bool>> {
  FirstRunNotifier(this._sharedPreferences) : super(const AsyncValue.loading()) {
    _init();
  }

  final SharedPreferencesAsync _sharedPreferences;

  Future<void> _init() async {
    try {
      final isFirstRun = await _checkIfFirstRun();
      state = AsyncValue.data(isFirstRun);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<bool> _checkIfFirstRun() async {
    final firstRunComplete = await _sharedPreferences.getBool(
      SharedPreferencesKeys.firstRunComplete.value,
    );
    return firstRunComplete != true;
  }

  Future<void> markFirstRunComplete() async {
    try {
      await _sharedPreferences.setBool(
        SharedPreferencesKeys.firstRunComplete.value,
        true,
      );
      state = const AsyncValue.data(false);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> resetFirstRun() async {
    try {
      await _sharedPreferences.remove(
        SharedPreferencesKeys.firstRunComplete.value,
      );
      state = const AsyncValue.data(true);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

final firstRunProvider = StateNotifierProvider<FirstRunNotifier, AsyncValue<bool>>((ref) {
  final sharedPreferences = ref.read(sharedPreferencesProvider);
  return FirstRunNotifier(sharedPreferences);
});