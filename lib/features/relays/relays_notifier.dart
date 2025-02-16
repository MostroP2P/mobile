import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/settings/settings_notifier.dart';
import 'relay.dart';

class RelaysNotifier extends StateNotifier<List<Relay>> {
  final SettingsNotifier settings;

  RelaysNotifier(this.settings) : super([]) {
    _loadRelays();
  }

  void _loadRelays() {
    final saved = settings.state;
    state = saved.relays.map((url) => Relay(url: url)).toList();
  }

  Future<void> _saveRelays() async {
    final relays = state.map((r) => r.url).toList();
    await settings.updateRelays(relays);
  }

  Future<void> addRelay(Relay relay) async {
    state = [...state, relay];
    await _saveRelays();
  }

  Future<void> updateRelay(Relay oldRelay, Relay updatedRelay) async {
    state = state.map((r) => r.url == oldRelay.url ? updatedRelay : r).toList();
    await _saveRelays();
  }

  Future<void> removeRelay(String url) async {
    state = state.where((r) => r.url != url).toList();
    await _saveRelays();
  }

  Future<void> refreshRelayHealth() async {
    state = state.map((r) => r.copyWith(isHealthy: true)).toList();
    await _saveRelays();
  }
}
