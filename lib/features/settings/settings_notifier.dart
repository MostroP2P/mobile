import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/data/models/enums/storage_keys.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsNotifier extends StateNotifier<Settings> {
  final SharedPreferencesAsync _prefs;
  static final String _storageKey = SharedPreferencesKeys.appSettings.value;

  SettingsNotifier(this._prefs) : super(_defaultSettings());

  static Settings _defaultSettings() {
    return Settings(
      relays: Config.nostrRelays,
      fullPrivacyMode: Config.fullPrivacyMode,
      mostroPublicKey: Config.mostroPubKey,
    );
  }

  Future<void> init() async {
    final settingsJson = await _prefs.getString(_storageKey);
    if (settingsJson != null) {
      try {
        final loaded = Settings.fromJson(jsonDecode(settingsJson));
        state = loaded;
      } catch (_) {
        state = _defaultSettings();
      }
    } else {
      state = _defaultSettings();
    }
  }

  Future<void> updateRelays(List<String> newRelays) async {
    state = state.copyWith(relays: newRelays);
    await _saveToPrefs();
  }

  Future<void> updatePrivacyMode(bool newValue) async {
    state = state.copyWith(privacyModeSetting: newValue);
    await _saveToPrefs();
  }

  Future<void> updateMostroInstance(String newValue) async {
    state = state.copyWith(mostroInstance: newValue);
    await _saveToPrefs();
  }

  Future<void> updateDefaultFiatCode(String newValue) async {
    state = state.copyWith(defaultFiatCode: newValue);
    await _saveToPrefs();
  }

  Future<void> _saveToPrefs() async {
    final jsonString = jsonEncode(state.toJson());
    await _prefs.setString(_storageKey, jsonString);
  }
}
