import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/repositories/mostro_repository.dart';
import 'package:mostro_mobile/services/mostro_service.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/providers/session_manager_provider.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';

final mostroServiceProvider = Provider<MostroService>((ref) {
  final sessionStorage = ref.watch(sessionManagerProvider);
  final nostrService = ref.watch(nostrServicerProvider);
  return MostroService(nostrService, sessionStorage);
});

final mostroRepositoryProvider = Provider<MostroRepository>((ref) {
  final mostroService = ref.watch(mostroServiceProvider);
  final secureStorage = ref.watch(secureStorageProvider);
  return MostroRepository(mostroService, secureStorage);
});
