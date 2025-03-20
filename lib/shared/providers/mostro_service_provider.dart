import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/services/mostro_service.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/providers/session_manager_provider.dart';

final mostroServiceProvider = Provider<MostroService>((ref) {
  final sessionStorage = ref.read(sessionNotifierProvider.notifier);
  final nostrService = ref.read(nostrServiceProvider);
  final settings = ref.read(settingsProvider);
  final mostroDatabase = ref.read(mostroStorageProvider);
  final mostroService =
      MostroService(nostrService, sessionStorage, settings, mostroDatabase);
  return mostroService;
});
