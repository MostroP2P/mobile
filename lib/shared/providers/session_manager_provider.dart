import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/repositories/session_manager.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';

final sessionManagerProvider = Provider<SessionManager>((ref) {
  final keyManager = ref.read(keyManagerProvider);
  final secureStorage = ref.read(secureStorageProvider);
  return SessionManager(keyManager, secureStorage);
});
