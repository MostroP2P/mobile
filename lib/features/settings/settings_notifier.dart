import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/data/models/enums/storage_keys.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/services/push_notification_service.dart';
import 'package:mostro_mobile/services/fcm_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsNotifier extends StateNotifier<Settings> {
  final SharedPreferencesAsync _prefs;
  final Ref? ref;
  static final String _storageKey = SharedPreferencesKeys.appSettings.value;

  /// Push notification service for unregistering tokens when disabled
  PushNotificationService? _pushService;
  FCMService? _fcmService;

  /// Set push notification services for integration
  void setPushServices(PushNotificationService? pushService, FCMService? fcmService) {
    _pushService = pushService;
    _fcmService = fcmService;
  }

  SettingsNotifier(this._prefs, {this.ref}) : super(_defaultSettings());

  static Settings _defaultSettings() {
    return Settings(
      relays: Config.nostrRelays,
      fullPrivacyMode: Config.fullPrivacyMode,
      mostroPublicKey: Config.mostroPubKey,
      selectedLanguage: null,
    );
  }

  Future<void> init() async {
    final settingsJson = await _prefs.getString(_storageKey);
    if (settingsJson != null) {
      try {
        state = Settings.fromJson(jsonDecode(settingsJson));
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
    final oldPubkey = state.mostroPublicKey;
    
    if (oldPubkey != newValue) {
      logger.i('Mostro change detected: $oldPubkey → $newValue');
      
      // COMPLETE RESET: Clear blacklist and user relays when changing Mostro
      state = state.copyWith(
        mostroPublicKey: newValue,
        blacklistedRelays: const [], // Blacklist vacío
        userRelays: const [],         // User relays vacíos
      );
      
      logger.i('Reset blacklist and user relays for new Mostro instance');
    } else {
      // Only update pubkey if it's the same (without reset)
      state = state.copyWith(mostroPublicKey: newValue);
    }
    
    await _saveToPrefs();
  }

  Future<void> updateDefaultFiatCode(String newValue) async {
    state = state.copyWith(defaultFiatCode: newValue);
    await _saveToPrefs();
  }

  Future<void> updateSelectedLanguage(String? newValue) async {
    state = state.copyWith(selectedLanguage: newValue);
    await _saveToPrefs();
  }

  Future<void> updateDefaultLightningAddress(String? newValue) async {
    if (newValue == null || newValue.trim().isEmpty) {
      // Clear the Lightning address
      state = state.copyWith(clearDefaultLightningAddress: true);
    } else {
      // Set the Lightning address
      state = state.copyWith(defaultLightningAddress: newValue.trim());
    }
    await _saveToPrefs();
  }

  /// Add a relay URL to the blacklist to prevent it from being auto-synced from Mostro
  Future<void> addToBlacklist(String relayUrl) async {
    final normalized = _normalizeUrl(relayUrl);
    final currentBlacklist = List<String>.from(state.blacklistedRelays);
    if (!currentBlacklist.contains(normalized)) {
      currentBlacklist.add(normalized);
      state = state.copyWith(blacklistedRelays: currentBlacklist);
      await _saveToPrefs();
      logger.i('Added relay to blacklist: $normalized');
    }
  }

  /// Remove a relay URL from the blacklist, allowing it to be auto-synced again
  Future<void> removeFromBlacklist(String relayUrl) async {
    final normalized = _normalizeUrl(relayUrl);
    final currentBlacklist = List<String>.from(state.blacklistedRelays);
    if (currentBlacklist.remove(normalized)) {
      state = state.copyWith(blacklistedRelays: currentBlacklist);
      await _saveToPrefs();
      logger.i('Removed relay from blacklist: $normalized');
    }
  }

  /// Check if a relay URL is blacklisted
  bool isRelayBlacklisted(String relayUrl) {
    return state.blacklistedRelays.contains(_normalizeUrl(relayUrl));
  }

  /// Normalize relay URL for consistent comparison
  /// Trims whitespace, converts to lowercase, and removes trailing slash
  String _normalizeUrl(String url) {
    var u = url.trim().toLowerCase();
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    return u;
  }

  /// Get all blacklisted relay URLs
  List<String> get blacklistedRelays => List<String>.from(state.blacklistedRelays);

  /// Clear all blacklisted relays (reset to allow all auto-sync)
  Future<void> clearBlacklist() async {
    if (state.blacklistedRelays.isNotEmpty) {
      state = state.copyWith(blacklistedRelays: const []);
      await _saveToPrefs();
      logger.i('Cleared all blacklisted relays');
    }
  }

  /// Update user relays list (user-added relays with metadata)
  Future<void> updateUserRelays(List<Map<String, dynamic>> newUserRelays) async {
    state = state.copyWith(userRelays: newUserRelays);
    await _saveToPrefs();
    logger.i('Updated user relays: ${newUserRelays.length} relays');
  }

  Future<void> _saveToPrefs() async {
    final jsonString = jsonEncode(state.toJson());
    await _prefs.setString(_storageKey, jsonString);
  }

  Future<void> updateLoggingEnabled(bool newValue) async {
    state = state.copyWith(isLoggingEnabled: newValue);
    MemoryLogOutput.isLoggingEnabled = newValue;
  }

  Future<void> updatePushNotificationsEnabled(bool newValue) async {
    state = state.copyWith(pushNotificationsEnabled: newValue);
    await _saveToPrefs();
    logger.i('Push notifications ${newValue ? 'enabled' : 'disabled'}');

    // When disabling, unregister all tokens and delete FCM token
    if (!newValue) {
      _unregisterPushTokens();
    }
  }

  /// Unregister all push tokens when user disables notifications
  void _unregisterPushTokens() {
    if (_pushService != null) {
      _pushService!.unregisterAllTokens().then((_) {
        logger.i('All push tokens unregistered');
      }).catchError((e) {
        logger.w('Failed to unregister push tokens: $e');
      });
    }

    if (_fcmService != null) {
      _fcmService!.deleteToken().then((_) {
        logger.i('FCM token deleted');
      }).catchError((e) {
        logger.w('Failed to delete FCM token: $e');
      });
    }
  }

  Future<void> updateNotificationSoundEnabled(bool newValue) async {
    state = state.copyWith(notificationSoundEnabled: newValue);
    await _saveToPrefs();
  }

  Future<void> updateNotificationVibrationEnabled(bool newValue) async {
    state = state.copyWith(notificationVibrationEnabled: newValue);
    await _saveToPrefs();
  }

  Settings get settings => state.copyWith();
}
