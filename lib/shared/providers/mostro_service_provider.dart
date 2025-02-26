import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/repositories/mostro_repository.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/services/mostro_service.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/providers/session_manager_provider.dart';

final mostroServiceProvider = Provider<MostroService>((ref) {
  final sessionStorage = ref.read(sessionManagerProvider);
  final nostrService = ref.read(nostrServiceProvider);
  final settings = ref.read(settingsProvider);
  final mostroService = MostroService(nostrService, sessionStorage, settings);

  ref.listen<Settings>(settingsProvider, (previous, next) {
    mostroService.updateSettings(next);
  });

  return mostroService;
});

final mostroRepositoryProvider = Provider<MostroRepository>((ref) {
  final mostroService = ref.read(mostroServiceProvider);
  final mostroDatabase = ref.read(mostroStorageProvider);

  final mostroRepository = MostroRepository(mostroService, mostroDatabase);

  return mostroRepository;
});
