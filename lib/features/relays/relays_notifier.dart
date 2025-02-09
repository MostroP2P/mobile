import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mostro_mobile/app/config.dart'; // Assumes Config.initialRelays exists.
import 'relay.dart';

class RelaysNotifier extends StateNotifier<List<Relay>> {
  final SharedPreferencesAsync sharedPreferences;
  static const _storageKey = 'relays';

  RelaysNotifier(this.sharedPreferences) : super([]) {
    _loadRelays();
  }

  Future<void> _loadRelays() async {
    final saved = await sharedPreferences.getString(_storageKey);
    if (saved != null) {
      final List<dynamic> jsonList = json.decode(saved) as List<dynamic>;
      state = jsonList.map((e) => Relay.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      // Use the initial relay list from Config (assumed to be List<String>)
      state = Config.nostrRelays
          .map((url) => Relay(url: url, isHealthy: true))
          .toList();
      await _saveRelays();
    }
  }

  Future<void> _saveRelays() async {
    final jsonString = json.encode(state.map((r) => r.toJson()).toList());
    await sharedPreferences.setString(_storageKey, jsonString);
  }

  Future<void> addRelay(Relay relay) async {
    state = [...state, relay];
    await _saveRelays();
  }

  Future<void> updateRelay(Relay updatedRelay) async {
    state = state.map((r) => r.url == updatedRelay.url ? updatedRelay : r).toList();
    await _saveRelays();
  }

  Future<void> removeRelay(String url) async {
    state = state.where((r) => r.url != url).toList();
    await _saveRelays();
  }

  /// For now, this simply sets all relays to “healthy.”
  /// In a real app, you’d ping each relay (or use some health endpoint)
  /// and update its status accordingly.
  Future<void> refreshRelayHealth() async {
    state = state.map((r) => r.copyWith(isHealthy: true)).toList();
    await _saveRelays();
  }
}
