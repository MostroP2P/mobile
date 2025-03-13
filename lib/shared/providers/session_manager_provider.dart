import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/repositories/session_manager.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';
import 'package:mostro_mobile/shared/providers/session_storage_provider.dart';

final sessionManagerProvider = Provider<SessionManager>((ref) {
  final keyManager = ref.read(keyManagerProvider);
  final sessionStorage = ref.read(sessionStorageProvider);
  final settings = ref.read(settingsProvider);

  final sessionManager = SessionManager(
    keyManager,
    sessionStorage,
    settings.copyWith(),
  );

  return sessionManager;
});

final sessionsProvider = Provider<List<Session>>((ref) {
  final sessionManager = ref.watch(sessionManagerProvider);
  return sessionManager.sessions;
});

final sessionNotifierProvider =
    StateNotifierProvider<SessionNotifier, List<Session>>((ref) {
  final manager = ref.watch(sessionManagerProvider);
  return SessionNotifier(manager);
});
