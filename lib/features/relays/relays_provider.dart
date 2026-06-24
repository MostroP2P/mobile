import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'relays_notifier.dart';
import 'relay.dart';

final relaysProvider =
    StateNotifierProvider<RelaysNotifier, List<Relay>>((ref) {
  final settings = ref.watch(
      settingsProvider.notifier); // Assume you have this provider defined.
  return RelaysNotifier(settings, ref);
});
