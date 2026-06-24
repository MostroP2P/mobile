import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';
import 'package:mostro_mobile/shared/providers/session_storage_provider.dart';

final sessionNotifierProvider =
    StateNotifierProvider<SessionNotifier, List<Session>>((ref) {
  final sessionStorage = ref.read(sessionStorageProvider);
  final settings = ref.read(settingsProvider);

  final sessionNotifier = SessionNotifier(
    ref,
    sessionStorage,
    settings.copyWith(),
  );

  ref.listen<Settings>(settingsProvider, (previous, next) {
    sessionNotifier.updateSettings(next);
  });

  return sessionNotifier;
});

final sessionProvider = StateProvider.family<Session?, String>((ref, id) {
  final notifier = ref.watch(sessionNotifierProvider);
  return notifier.where((s) => s.orderId == id).firstOrNull;
});
