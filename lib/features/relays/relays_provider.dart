import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';
import 'relays_notifier.dart';
import 'relay.dart';

final relaysProvider = StateNotifierProvider<RelaysNotifier, List<Relay>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider); // Assume you have this provider defined.
  return RelaysNotifier(prefs);
});
