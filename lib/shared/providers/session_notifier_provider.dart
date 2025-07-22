import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';
import 'package:mostro_mobile/shared/providers/session_storage_provider.dart';

final sessionNotifierProvider =
    StateNotifierProvider<SessionNotifier, List<Session>>((ref) {
  final keyManager = ref.read(keyManagerProvider);
  final sessionStorage = ref.read(sessionStorageProvider);
  final settings = ref.read(settingsProvider);
  return SessionNotifier(
    keyManager,
    sessionStorage,
    settings.copyWith(),
  );
});

final sessionProvider = StateProvider.family<Session?, String>((ref, id) {
  final notifier = ref.watch(sessionNotifierProvider);
  return notifier.where((s) => s.orderId == id).firstOrNull;
});
