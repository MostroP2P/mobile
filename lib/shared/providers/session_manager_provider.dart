import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/repositories/session_manager.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/shared/providers/session_storage_provider.dart';

final sessionManagerProvider = Provider<SessionManager>((ref) {
  final keyManager = ref.read(keyManagerProvider);
  final sessionStorage = ref.read(sessionStorageProvider);
  return SessionManager(keyManager, sessionStorage);
});
